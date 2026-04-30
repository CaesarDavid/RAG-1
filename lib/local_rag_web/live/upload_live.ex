defmodule LocalRagWeb.UploadLive do
  use LocalRagWeb, :live_view

  require Logger

  alias LocalRag.{Documents, Processor}

  @accepted_types ~w(.pdf .txt .md .csv .json)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(LocalRag.PubSub, "documents")
    end

    socket =
      socket
      |> assign(:documents, Documents.list_documents())
      |> assign(:uploading, false)
      |> allow_upload(:files,
        accept: @accepted_types,
        max_entries: 20,
        max_file_size: 50_000_000,
        auto_upload: false
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel-upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :files, ref)}
  end

  @impl true
  def handle_event("upload", _params, socket) do
    socket = assign(socket, :uploading, true)

    uploaded_docs =
      consume_uploaded_entries(socket, :files, fn %{path: tmp_path}, entry ->
        ext = Path.extname(entry.client_name)
        content_type = entry.client_type || "application/octet-stream"
        name = Path.rootname(entry.client_name)

        with {:ok, doc} <-
               Documents.create_document(%{
                 name: name,
                 original_filename: entry.client_name,
                 content_type: content_type,
                 file_size: entry.client_size
               }) do
          # Copy from the LiveView temp path to our persistent uploads dir
          dest = Path.join(Processor.uploads_dir(), "#{doc.id}#{ext}")
          File.cp!(tmp_path, dest)

          # Kick off async processing
          Processor.process_async(doc)

          {:ok, doc}
        end
      end)

    docs_ok = Enum.filter(uploaded_docs, &match?({:ok, _}, &1))
    docs_err = Enum.filter(uploaded_docs, &match?({:error, _}, &1))

    flash_msg =
      case {length(docs_ok), length(docs_err)} do
        {0, n} -> "Failed to upload #{n} file(s)."
        {ok, 0} -> "#{ok} file(s) queued for processing."
        {ok, n} -> "#{ok} file(s) queued for processing. #{n} file(s) failed."
      end

    flash_type = if docs_err == [], do: :info, else: :error

    socket =
      socket
      |> assign(:uploading, false)
      |> assign(:documents, Documents.list_documents())
      |> put_flash(flash_type, flash_msg)

    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    doc = Documents.get_document!(id)
    {:ok, _} = Documents.delete_document(doc)

    # Remove the stored file
    ext = Path.extname(doc.original_filename)
    path = Path.join(Processor.uploads_dir(), "#{doc.id}#{ext}")

    case File.rm(path) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Could not remove upload file #{path}: #{inspect(reason)}")
    end

    {:noreply,
     socket
     |> assign(:documents, Documents.list_documents())
     |> put_flash(:info, "Document deleted.")}
  end

  @impl true
  def handle_info({:document_updated, doc}, socket) do
    docs =
      Enum.map(socket.assigns.documents, fn d ->
        if d.id == doc.id, do: doc, else: d
      end)

    {:noreply, assign(socket, :documents, docs)}
  end

  # ---------------------------------------------------------------------------
  # Helpers exposed to template
  # ---------------------------------------------------------------------------

  def status_badge("pending"), do: {"Pending", "badge-neutral"}
  def status_badge("processing"), do: {"Processing…", "badge-warning"}
  def status_badge("ready"), do: {"Ready", "badge-success"}
  def status_badge("error"), do: {"Error", "badge-error"}
  def status_badge(_), do: {"Unknown", "badge-ghost"}

  def humanize_bytes(nil), do: "—"
  def humanize_bytes(b) when b < 1_024, do: "#{b} B"
  def humanize_bytes(b) when b < 1_048_576, do: "#{Float.round(b / 1_024, 1)} KB"
  def humanize_bytes(b), do: "#{Float.round(b / 1_048_576, 1)} MB"
end
