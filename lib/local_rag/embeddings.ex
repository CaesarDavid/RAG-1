defmodule LocalRag.Embeddings do
  @moduledoc """
  Calls LM Studio's OpenAI-compatible API to produce bge-m3 embeddings
  and LLM chat completions.

  Endpoints used:
    POST /v1/embeddings        – text embeddings
    POST /v1/chat/completions  – answer generation
    GET  /v1/models            – health check
  """

  defp cfg(key), do: Application.fetch_env!(:local_rag, :rag)[key]
  defp base, do: cfg(:lm_studio_url)

  @doc """
  Embeds a single text string.
  Returns `{:ok, [float]}` or `{:error, reason}`.
  """
  def embed(text) when is_binary(text) do
    case embed_batch([text]) do
      {:ok, [embedding]} -> {:ok, embedding}
      {:ok, []} -> {:error, "LM Studio returned no embeddings"}
      {:error, _} = err -> err
    end
  end

  @doc """
  Embeds a list of texts in one request, chunking locally to prevent timeouts.
  Returns `{:ok, [[float]]}` or `{:error, reason}`.
  """
  def embed_batch(texts) when is_list(texts) do
    url = base() <> "/v1/embeddings"
    model = cfg(:embedding_model)

    require Logger

    batches = Enum.chunk_every(texts, 50)
    total_batches = length(batches)

    # Process in chunks of 50 to avoid timing out LM Studio on huge documents
    results =
      batches
      |> Enum.with_index(1)
      |> Enum.map(fn {batch, idx} ->
        Logger.info("Processing embedding batch #{idx}/#{total_batches}")

        case Req.post(url, json: %{model: model, input: batch}, receive_timeout: 300_000) do
          {:ok, %{status: 200, body: %{"data" => data}}} ->
            embeddings =
              data
              |> Enum.sort_by(& &1["index"])
              |> Enum.map(& &1["embedding"])

            {:ok, embeddings}

          {:ok, %{status: status, body: body}} ->
            {:error, "LM Studio embed returned #{status}: #{inspect(body)}"}

          {:error, reason} ->
            {:error, "HTTP error: #{inspect(reason)}"}
        end
      end)

    # If any chunk failed, return the first error. Else return flattened embeddings.
    if failed = Enum.find(results, &match?({:error, _}, &1)) do
      failed
    else
      {:ok, Enum.flat_map(results, fn {:ok, embeddings} -> embeddings end)}
    end
  end

  @doc """
  Generates an answer using LM Studio's chat completions endpoint.
  Returns `{:ok, answer_string}` or `{:error, reason}`.
  """
  def generate(prompt) when is_binary(prompt) do
    url = base() <> "/v1/chat/completions"
    model = cfg(:generation_model)

    body = %{
      model: model,
      messages: [
        %{role: "system", content: "You are a helpful assistant for a local business."},
        %{role: "user", content: prompt}
      ],
      stream: false,
      temperature: 0.3
    }

    case Req.post(url, json: body, receive_timeout: 300_000) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, String.trim(content)}

      {:ok, %{status: status, body: resp_body}} ->
        {:error, "LM Studio generate returned #{status}: #{inspect(resp_body)}"}

      {:error, reason} ->
        {:error, "HTTP error: #{inspect(reason)}"}
    end
  end

  @doc """
  Returns :ok if LM Studio is reachable.
  """
  def health_check do
    case Req.get(base() <> "/v1/models", receive_timeout: 5_000) do
      {:ok, %{status: 200}} -> :ok
      _ -> :error
    end
  end
end
