defmodule LocalRag.Chunks.Chunk do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chunks" do
    field :content, :string
    field :chunk_index, :integer
    field :embedding, Pgvector.Ecto.Vector

    belongs_to :document, LocalRag.Documents.Document

    timestamps(type: :utc_datetime)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [:document_id, :content, :chunk_index, :embedding])
    |> validate_required([:document_id, :content, :chunk_index])
  end
end
