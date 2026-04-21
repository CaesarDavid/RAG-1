defmodule LocalRag.Documents do
  alias LocalRag.Turso
  alias LocalRag.Documents.Document

  def list_documents do
    case Turso.query("SELECT * FROM documents ORDER BY inserted_at DESC") do
      {:ok, rows} -> Enum.map(rows, &Document.from_row/1)
      {:error, _} -> []
    end
  end

  def get_document!(id) do
    case Turso.query("SELECT * FROM documents WHERE id = ? LIMIT 1", [id]) do
      {:ok, [row | _]} -> Document.from_row(row)
      {:ok, []} -> raise "Document #{id} not found"
      {:error, reason} -> raise "Turso error: #{reason}"
    end
  end

  def create_document(attrs) do
    changeset = Document.changeset(%Document{}, attrs)

    if changeset.valid? do
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      data = changeset.changes

      case Turso.execute(
             """
             INSERT INTO documents (name, original_filename, content_type, file_size, status, chunk_count, inserted_at, updated_at)
             VALUES (?, ?, ?, ?, 'pending', 0, ?, ?)
             """,
             [
               data[:name],
               data[:original_filename],
               data[:content_type],
               data[:file_size],
               now,
               now
             ]
           ) do
        {:ok, %{last_insert_id: id}} -> {:ok, get_document!(id)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, changeset}
    end
  end

  def update_document(%Document{id: id} = doc, attrs) do
    changeset = Document.changeset(doc, attrs)

    if changeset.valid? do
      now = DateTime.utc_now() |> DateTime.to_iso8601()
      changes = changeset.changes

      {set_clauses, values} =
        changes
        |> Enum.map(fn {k, v} -> {"#{k} = ?", v} end)
        |> Enum.unzip()

      set_clauses = Enum.join(set_clauses, ", ")
      sql = "UPDATE documents SET #{set_clauses}, updated_at = ? WHERE id = ?"

      case Turso.execute(sql, values ++ [now, id]) do
        {:ok, _} -> {:ok, get_document!(id)}
        {:error, reason} -> {:error, reason}
      end
    else
      {:error, changeset}
    end
  end

  def delete_document(%Document{id: id}) do
    # Cascade delete chunks first
    Turso.execute("DELETE FROM chunks WHERE document_id = ?", [id])
    Turso.execute("DELETE FROM documents WHERE id = ?", [id])
  end

  def set_status(%Document{} = doc, status, opts \\ []) do
    attrs = %{status: status}
    attrs = if msg = opts[:error], do: Map.put(attrs, :error_message, msg), else: attrs
    attrs = if count = opts[:chunk_count], do: Map.put(attrs, :chunk_count, count), else: attrs
    update_document(doc, attrs)
  end
end
