defmodule LocalRag.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :name, :string, null: false
      add :original_filename, :string, null: false
      add :content_type, :string, null: false
      add :file_size, :integer
      # pending | processing | ready | error
      add :status, :string, default: "pending", null: false
      add :error_message, :text
      add :chunk_count, :integer, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:documents, [:status])
  end
end
