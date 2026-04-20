defmodule LocalRag.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :name, :string
    field :original_filename, :string
    field :content_type, :string
    field :file_size, :integer
    field :status, :string, default: "pending"
    field :error_message, :string
    field :chunk_count, :integer, default: 0

    has_many :chunks, LocalRag.Chunks.Chunk

    timestamps(type: :utc_datetime)
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
end
