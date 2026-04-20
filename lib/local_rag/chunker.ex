defmodule LocalRag.Chunker do
  @moduledoc """
  Splits text into overlapping chunks suitable for embedding.

  Strategy: split on paragraph/sentence boundaries first, then enforce
  a hard character limit. Overlap keeps context across chunk edges.
  """

  defp cfg(key), do: Application.fetch_env!(:local_rag, :rag)[key]

  @doc """
  Split `text` into a list of chunk strings.
  """
  def chunk(text, opts \\ []) do
    chunk_size = opts[:chunk_size] || cfg(:chunk_size)
    overlap = opts[:chunk_overlap] || cfg(:chunk_overlap)

    text
    |> split_into_paragraphs()
    |> merge_paragraphs(chunk_size, overlap)
    |> Enum.reject(&(String.trim(&1) == ""))
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Split on blank lines (paragraphs), then on sentence endings as fallback.
  defp split_into_paragraphs(text) do
    text
    |> String.split(~r/\n{2,}/)
    |> Enum.flat_map(fn para ->
      if String.length(para) > 800 do
        # Long paragraphs: split on sentence endings
        String.split(para, ~r/(?<=[.!?])\s+/)
      else
        [para]
      end
    end)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # Greedily merge sentences/paragraphs until chunk_size is reached,
  # then start a new chunk with `overlap` characters carried over.
  defp merge_paragraphs(paragraphs, chunk_size, overlap) do
    do_merge(paragraphs, chunk_size, overlap, [], [])
  end

  defp do_merge([], _size, _overlap, current_parts, acc) do
    current = Enum.reverse(current_parts) |> Enum.join(" ")

    if String.trim(current) == "" do
      Enum.reverse(acc)
    else
      Enum.reverse([current | acc])
    end
  end

  defp do_merge([para | rest], chunk_size, overlap, current_parts, acc) do
    current = Enum.reverse(current_parts) |> Enum.join(" ")
    candidate = if current == "", do: para, else: current <> " " <> para

    if String.length(candidate) <= chunk_size do
      do_merge(rest, chunk_size, overlap, [para | current_parts], acc)
    else
      # Emit current chunk, carry overlap into next chunk
      overlap_text = String.slice(current, max(0, String.length(current) - overlap)..-1//1)
      new_parts = if overlap_text == "", do: [para], else: [para, overlap_text]
      do_merge(rest, chunk_size, overlap, new_parts, [current | acc])
    end
  end
end
