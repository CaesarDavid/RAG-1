defmodule LocalRag.Extractor do
  @moduledoc """
  Extracts plain text from uploaded files.

  Supported types:
    - .txt / .md    – read directly
    - .json         – pretty-printed key/value pairs
    - .csv          – rows joined as "key: value" lines
    - .pdf          – via `pdftotext` (poppler, installed via `brew install poppler`)

  Returns {:ok, text} | {:error, reason}.
  """

  NimbleCSV.define(LocalRag.CSV, separator: ",", escape: "\"")

  @doc """
  Extract text from `path` based on `content_type` or file extension.
  """
  def extract(path, content_type \\ nil) do
    ext = path |> Path.extname() |> String.downcase()

    cond do
      ext in [".txt", ".md"] or content_type in ["text/plain", "text/markdown"] ->
        read_text(path)

      ext == ".json" or content_type == "application/json" ->
        extract_json(path)

      ext == ".csv" or content_type == "text/csv" ->
        extract_csv(path)

      ext == ".pdf" or content_type == "application/pdf" ->
        extract_pdf(path)

      true ->
        # Try reading as plain text for unknown types
        read_text(path)
    end
  end

  defp read_text(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, String.trim(content)}
      {:error, reason} -> {:error, "Cannot read file: #{reason}"}
    end
  end

  defp extract_json(path) do
    with {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, json_to_text(data)}
    else
      {:error, %Jason.DecodeError{} = e} -> {:error, "Invalid JSON: #{Exception.message(e)}"}
      {:error, reason} -> {:error, "Cannot read file: #{reason}"}
    end
  end

  defp json_to_text(data) when is_map(data) do
    data
    |> Enum.map(fn {k, v} -> "#{k}: #{json_to_text(v)}" end)
    |> Enum.join("\n")
  end

  defp json_to_text(data) when is_list(data) do
    data
    |> Enum.map(&json_to_text/1)
    |> Enum.join("\n")
  end

  defp json_to_text(data), do: to_string(data)

  defp extract_csv(path) do
    case File.read(path) do
      {:ok, content} ->
        rows =
          content
          |> LocalRag.CSV.parse_string(skip_headers: false)
          |> Enum.map(&Enum.join(&1, " | "))
          |> Enum.join("\n")

        {:ok, rows}

      {:error, reason} ->
        {:error, "Cannot read file: #{reason}"}
    end
  end

  defp extract_pdf(path) do
    case System.find_executable("pdftotext") do
      nil ->
        {:error, "pdftotext not found. Install poppler: brew install poppler"}

      pdftotext ->
        case System.cmd(pdftotext, [path, "-"], stderr_to_stdout: true) do
          {text, 0} -> {:ok, String.trim(text)}
          {output, code} -> {:error, "pdftotext exited #{code}: #{output}"}
        end
    end
  end
end
