defmodule LocalRag.Documents do
  import Ecto.Query
  alias LocalRag.Repo
  alias LocalRag.Documents.Document

  def list_documents do
    Repo.all(from d in Document, order_by: [desc: d.inserted_at])
  end

  def get_document!(id), do: Repo.get!(Document, id)

  def create_document(attrs) do
    %Document{}
    |> Document.changeset(attrs)
    |> Repo.insert()
  end

  def update_document(%Document{} = document, attrs) do
    document
    |> Document.changeset(attrs)
    |> Repo.update()
  end

  def delete_document(%Document{} = document) do
    Repo.delete(document)
  end

  def set_status(%Document{} = document, status, opts \\ []) do
    attrs = %{status: status}
    attrs = if msg = opts[:error], do: Map.put(attrs, :error_message, msg), else: attrs
    attrs = if count = opts[:chunk_count], do: Map.put(attrs, :chunk_count, count), else: attrs
    update_document(document, attrs)
  end
end
