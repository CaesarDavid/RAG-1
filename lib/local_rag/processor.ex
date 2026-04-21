defmodule LocalRag.Processor do
  @moduledoc """
  Ingestion pipeline: extract text → chunk → embed → store.

  Each document is processed in a supervised Task so the LiveView
  can continue serving requests. Progress is broadcast over PubSub
  so the upload UI can update in real time.
  """

  require Logger

  alias LocalRag.{Documents, Chunks, Embeddings, Extractor, Chunker}

  @pubsub LocalRag.PubSub
  @topic "documents"

  @doc """
  Kick off async processing for a document that already exists in the DB.
  """
  def process_async(document) do
    Task.Supervisor.start_child(LocalRag.TaskSupervisor, fn ->
      process(document)
    end)
  end

  @doc """
  Synchronous processing pipeline – useful for tests or scripts.
  """
  def process(%{id: id} = document) do
    case Documents.set_status(document, "processing") do
      {:ok, doc} ->
        broadcast(doc)

        result =
          try do
            do_process(doc)
          rescue
            e -> {:error, Exception.message(e)}
          end

        Logger.info("do_process returned: #{inspect(result)}")

        case result do
          {:ok, chunk_count} ->
            case Documents.set_status(doc, "ready", chunk_count: chunk_count) do
              {:ok, updated} ->
                broadcast(updated)
                {:ok, updated}

              {:error, reason} ->
                Logger.error("Failed to mark document #{id} as ready: #{inspect(reason)}")
                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Processing failed for document #{id}: #{reason}")

            case Documents.set_status(doc, "error", error: inspect(reason)) do
              {:ok, updated} -> broadcast(updated)
              {:error, err} -> Logger.error("Also failed to set error status for document #{id}: #{inspect(err)}")
            end

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Failed to set document status to processing: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp do_process(document) do
    path = tmp_path(document)
    Logger.info("Starting processing for document #{document.id} at path #{path}")

    with {:ok, text} <- Extractor.extract(path, document.content_type),
         _ <- Logger.info("Extracted text, length: #{String.length(text)}"),
         {:ok, chunks} <- chunk_text(text),
         _ <- Logger.info("Chunked into #{length(chunks)} chunks, embedding now..."),
         {:ok, embeddings} <- Embeddings.embed_batch(chunks),
         _ <- Logger.info("Received #{length(embeddings)} embeddings, storing..."),
         {:ok, count} <- store_chunks(document.id, chunks, embeddings) do
      Logger.info("Stored #{count} chunks for document #{document.id}")
      {:ok, count}
    end
  end

  defp chunk_text(text) do
    chunks = Chunker.chunk(text)

    if chunks == [] do
      {:error, "No text content could be extracted from the file."}
    else
      {:ok, chunks}
    end
  end

  defp store_chunks(document_id, chunks, embeddings) do
    # Clear any previous chunks (re-processing scenario)
    Chunks.delete_for_document(document_id)
    pairs = Enum.zip(chunks, embeddings)
    Chunks.insert_chunks(document_id, pairs)
  end

  # Files are stored temporarily under priv/uploads/<document_id>.<ext>
  defp tmp_path(document) do
    ext = Path.extname(document.original_filename)
    Path.join(uploads_dir(), "#{document.id}#{ext}")
  end

  def uploads_dir do
    dir = Application.get_env(:local_rag, :uploads_dir, "priv/uploads")
    File.mkdir_p!(dir)
    dir
  end

  defp broadcast(document) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, {:document_updated, document})
  end
end
