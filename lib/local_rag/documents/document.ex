defmodule LocalRag.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  # Embedded schema: used for changeset validation and struct definition only.
  # All persistence goes through LocalRag.Turso.
  embedded_schema do
    field :name, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :status, :string, default: "pending"
    field :error_message, :string
    field :chunk_count, :integer, default: 0
    field :inserted_at, :utc_datetime
    field :updated_at, :utc_datetime
  end

  def changeset(document, attrs) do
    document
    |> cast(attrs, [
      :name,
      :original_filename,
      :content_type,
      :file_size,
      :status,
      :error_message,
      :chunk_count
    ])
    |> validate_required([:name, :original_filename, :content_type])
    |> validate_inclusion(:status, ~w(pending processing ready error))
  end

  @doc "Build a Document struct from a Turso row map (string keys)."
  def from_row(row) do
    %__MODULE__{
      id: row["id"],
      name: row["name"],
      original_filename: row["original_filename"],
      content_type: row["content_type"],
      file_size: row["file_size"],
      status: row["status"],
      error_message: row["error_message"],
      chunk_count: row["chunk_count"] || 0,
      inserted_at: parse_datetime(row["inserted_at"]),
      updated_at: parse_datetime(row["updated_at"])
    }
  end

  defp parse_datetime(nil), do: nil

  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
