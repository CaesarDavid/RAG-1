defmodule LocalRag.Repo.Migrations.CreateChunks do
  use Ecto.Migration

  def change do
    create table(:chunks) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :content, :text, null: false
      add :chunk_index, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:chunks, [:document_id])

    # Add vector column separately with raw SQL because Ecto doesn't natively
    # support the vector type – pgvector extension must already exist.
    execute(
      "ALTER TABLE chunks ADD COLUMN embedding vector(1024)",
      "ALTER TABLE chunks DROP COLUMN embedding"
    )

    # IVFFlat index for approximate nearest-neighbour search.
    # Built after data is loaded; rebuild with SET ivfflat.probes for accuracy.
    execute(
      "CREATE INDEX IF NOT EXISTS chunks_embedding_idx ON chunks USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100)",
      "DROP INDEX IF EXISTS chunks_embedding_idx"
    )
  end
end
