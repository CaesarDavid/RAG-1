defmodule LocalRag.Turso do
  @moduledoc """
  HTTP client for Turso's libSQL v2 pipeline API.

  Turso exposes an HTTP endpoint at:
    POST https://{db}.turso.io/v2/pipeline

  All SQL is sent as JSON with positional `?` parameters.
  Vectors are passed as JSON array strings and wrapped with `vector32(?)` in SQL.
  """

  defp config, do: Application.fetch_env!(:local_rag, :turso)

  # Convert libsql:// scheme to https:// for the HTTP pipeline API
  defp pipeline_url do
    base =
      case config()[:url] do
        "libsql://" <> rest -> "https://#{rest}"
        other -> other
      end

    base <> "/v2/pipeline"
  end

  defp token, do: config()[:token]

  @doc """
  Execute a single SELECT-style SQL statement.
  Returns `{:ok, [%{col => val}]}` or `{:error, reason}`.
  """
  def query(sql, args \\ []) do
    case run_pipeline([{sql, args}]) do
      {:ok, [result | _]} -> {:ok, result.rows}
      {:error, _} = err -> err
    end
  end

  @doc """
  Execute a single INSERT / UPDATE / DELETE statement.
  Returns `{:ok, %{rows_affected: n, last_insert_id: id}}` or `{:error, reason}`.
  """
  def execute(sql, args \\ []) do
    case run_pipeline([{sql, args}]) do
      {:ok, [result | _]} ->
        {:ok, %{rows_affected: result.rows_affected, last_insert_id: result.last_insert_id}}

      {:error, _} = err ->
        err
    end
  end

  @doc """
  Execute multiple `{sql, args}` pairs in a single HTTP round-trip.
  Returns `{:ok, [results]}` or `{:error, reason}`.
  """
  def pipeline(sql_args_list) when is_list(sql_args_list) do
    run_pipeline(sql_args_list)
  end

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  defp run_pipeline(sql_args_list) do
    requests =
      Enum.map(sql_args_list, fn {sql, args} ->
        %{"type" => "execute", "stmt" => build_stmt(sql, args)}
      end) ++ [%{"type" => "close"}]

    case Req.post(pipeline_url(),
           json: %{"requests" => requests},
           headers: [{"authorization", "Bearer #{token()}"}],
           receive_timeout: 30_000
         ) do
      {:ok, %{status: 200, body: %{"results" => results}}} ->
        parse_results(results)

      {:ok, %{status: status, body: body}} ->
        {:error, "Turso HTTP #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Turso connection error: #{inspect(reason)}"}
    end
  end

  defp parse_results(results) do
    execute_results = Enum.reject(results, &(get_in(&1, ["response", "type"]) == "close"))

    Enum.reduce_while(execute_results, {:ok, []}, fn item, {:ok, acc} ->
      case item do
        %{"type" => "ok", "response" => %{"result" => raw}} ->
          {:cont, {:ok, acc ++ [parse_result(raw)]}}

        %{"type" => "error", "error" => err} ->
          {:halt, {:error, err["message"] || "Unknown Turso error"}}

        _ ->
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp parse_result(raw) do
    col_names = (raw["cols"] || []) |> Enum.map(& &1["name"])

    rows =
      (raw["rows"] || [])
      |> Enum.map(fn row ->
        col_names
        |> Enum.zip(Enum.map(row, &decode_value/1))
        |> Map.new()
      end)

    %{
      rows: rows,
      rows_affected: raw["affected_row_count"] || 0,
      last_insert_id: raw["last_insert_rowid"]
    }
  end

  defp build_stmt(sql, []), do: %{"sql" => sql}

  defp build_stmt(sql, args),
    do: %{"sql" => sql, "args" => Enum.map(args, &encode_value/1)}

  defp encode_value(nil), do: %{"type" => "null", "value" => nil}
  defp encode_value(v) when is_integer(v), do: %{"type" => "integer", "value" => to_string(v)}
  defp encode_value(v) when is_float(v), do: %{"type" => "float", "value" => v}
  defp encode_value(v) when is_binary(v), do: %{"type" => "text", "value" => v}
  defp encode_value(%DateTime{} = v), do: %{"type" => "text", "value" => DateTime.to_iso8601(v)}

  defp decode_value(%{"type" => "null"}), do: nil
  defp decode_value(%{"type" => "integer", "value" => v}), do: String.to_integer(v)
  defp decode_value(%{"type" => "float", "value" => v}), do: v
  defp decode_value(%{"type" => "text", "value" => v}), do: v
  defp decode_value(%{"type" => "blob"}), do: nil
  defp decode_value(nil), do: nil
end
