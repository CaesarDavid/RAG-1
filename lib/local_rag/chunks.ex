defmodule LocalRag.Chunks do
  import Ecto.Query
  alias LocalRag.Repo
  alias LocalRag.Chunks.Chunk

  def insert_chunks(document_id, chunks_with_embeddings) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries =
      chunks_with_embeddings
      |> Enum.with_index()
      |> Enum.map(fn {{content, embedding}, idx} ->
        %{
          document_id: document_id,
          content: content,
          chunk_index: idx,
          embedding: Pgvector.new(embedding),
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.insert_all(Chunk, entries)
  end

  def delete_for_document(document_id) do
    Repo.delete_all(from c in Chunk, where: c.document_id == ^document_id)
  end

  @doc """
  Returns the top-k chunks most similar to `query_embedding` (cosine distance).
  Only considers chunks from documents with status "ready".
  """
  def similarity_search(query_embedding, top_k \\ 5) do
    vec = Pgvector.new(query_embedding)

    Repo.all(
      from c in Chunk,
        join: d in assoc(c, :document),
        where: d.status == "ready",
        order_by: fragment("embedding <=> ?", ^vec),
        limit: ^top_k,
        select: %{content: c.content, document_name: d.name, chunk_index: c.chunk_index}
    )
  end
end
