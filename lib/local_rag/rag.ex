defmodule LocalRag.RAG do
  @moduledoc """
  Retrieval-Augmented Generation.

  1. Embed the user question with bge-m3
  2. Retrieve the top-k most relevant chunks via cosine similarity
  3. Build a prompt and generate an answer with Ollama
  """

  alias LocalRag.{Embeddings, Chunks}

  defp cfg(key), do: Application.fetch_env!(:local_rag, :rag)[key]

  @doc """
  Answer `question` using the knowledge base.

  Returns `{:ok, %{answer: string, sources: [%{document_name, chunk_index, content}]}}`.
  """
  def query(question) when is_binary(question) do
    top_k = cfg(:top_k)

    with {:ok, query_embedding} <- Embeddings.embed(question),
         chunks when chunks != [] <- Chunks.similarity_search(query_embedding, top_k) do
      prompt = build_prompt(question, chunks)

      case Embeddings.generate(prompt) do
        {:ok, answer} ->
          {:ok, %{answer: answer, sources: chunks}}

        {:error, reason} ->
          {:error, reason}
      end
    else
      [] ->
        {:ok,
         %{
           answer:
             "I couldn't find relevant information in the knowledge base to answer that question.",
           sources: []
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp build_prompt(question, chunks) do
    context =
      chunks
      |> Enum.with_index(1)
      |> Enum.map(fn {chunk, i} ->
        "[#{i}] (#{chunk.document_name})\n#{chunk.content}"
      end)
      |> Enum.join("\n\n")

    """
    You are a helpful assistant for a local business. Use ONLY the context below to answer the question.
    If the context does not contain enough information, say so honestly — do not invent facts.

    Context:
    #{context}

    Question: #{question}

    Answer:
    """
  end
end
