defmodule LocalRag.Chunks.Chunk do
  # Minimal struct used only for type clarity.
  # All persistence goes through LocalRag.Turso.
  defstruct [:id, :document_id, :content, :chunk_index, :inserted_at, :updated_at]
end
