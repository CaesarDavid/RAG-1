defmodule Mix.Tasks.LocalRag.Migrate do
  @shortdoc "Create Turso tables for LocalRag"
  use Mix.Task

  @migrations [
    """
    CREATE TABLE IF NOT EXISTS documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      original_filename TEXT NOT NULL,
      content_type TEXT NOT NULL,
      file_size INTEGER,
      status TEXT NOT NULL DEFAULT 'pending',
      error_message TEXT,
      chunk_count INTEGER NOT NULL DEFAULT 0,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS documents_status_idx ON documents (status)",
    """
    CREATE TABLE IF NOT EXISTS chunks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      document_id INTEGER NOT NULL,
      content TEXT NOT NULL,
      chunk_index INTEGER NOT NULL,
      embedding F32_BLOB(1024),
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
    """,
    "CREATE INDEX IF NOT EXISTS chunks_document_id_idx ON chunks (document_id)",
    "CREATE INDEX IF NOT EXISTS chunks_embedding_idx ON chunks (libsql_vector_idx(embedding, 'metric=cosine'))"
  ]

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.config")
    Application.ensure_all_started(:req)

    Mix.shell().info("Running Turso migrations...")

    stmts = Enum.map(@migrations, &{String.trim(&1), []})

    case LocalRag.Turso.pipeline(stmts) do
      {:ok, _} ->
        Mix.shell().info("Turso schema ready.")

      {:error, reason} ->
        Mix.raise("Turso migration failed: #{reason}")
    end
  end
end
