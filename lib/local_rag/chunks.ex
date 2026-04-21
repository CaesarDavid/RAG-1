defmodule LocalRag.Chunks do
  require Logger

  alias LocalRag.Turso

  @doc """
  Bulk-insert chunks with their embeddings using a pipeline.
  Embeddings are passed as JSON arrays; Turso's `vector32()` function converts them.
  Returns `{:ok, count}` or `{:error, reason}`.
  """
  @batch_size 50

  def insert_chunks(document_id, chunks_with_embeddings) do
    now = DateTime.utc_now() |> DateTime.to_iso8601()

    stmts =
      chunks_with_embeddings
      |> Enum.with_index()
      |> Enum.map(fn {{content, embedding}, idx} ->
        embedding_json = Jason.encode!(embedding)

        {"""
         INSERT INTO chunks (document_id, content, chunk_index, embedding, inserted_at, updated_at)
         VALUES (?, ?, ?, vector32(?), ?, ?)
         """, [document_id, content, idx, embedding_json, now, now]}
      end)

    stmts
    |> Enum.chunk_every(@batch_size)
    |> Enum.reduce_while({:ok, 0}, fn batch, {:ok, count} ->
      case Turso.pipeline(batch) do
        {:ok, results} -> {:cont, {:ok, count + length(results)}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  def delete_for_document(document_id) do
    Turso.execute("DELETE FROM chunks WHERE document_id = ?", [document_id])
  end

  @doc """
  Returns the top-k chunks most similar to `query_embedding` (cosine distance).
  Only considers chunks from documents with status 'ready'.
  Uses Turso's vector_top_k() ANN function for index-backed search.
  """
  def similarity_search(query_embedding, top_k \\ 5) do
    embedding_json = Jason.encode!(query_embedding)

    # Request extra candidates from the ANN index to allow for status filtering.
    ann_k = top_k * 3

    sql = """
    SELECT c.content, d.name AS document_name, c.chunk_index
    FROM vector_top_k('chunks_embedding_idx', vector32(?), #{ann_k}) v
    JOIN chunks c ON c.rowid = v.id
    JOIN documents d ON d.id = c.document_id
    WHERE d.status = 'ready'
    ORDER BY vector_distance_cos(c.embedding, vector32(?)) ASC
    LIMIT #{top_k}
    """

    case Turso.query(sql, [embedding_json, embedding_json]) do
      {:ok, rows} ->
        Enum.map(rows, fn row ->
          %{
            content: row["content"],
            document_name: row["document_name"],
            chunk_index: row["chunk_index"]
          }
        end)

      {:error, reason} ->
        Logger.error("Similarity search failed: #{inspect(reason)}")
        []
    end
  end
end
