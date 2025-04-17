defmodule Sandbox.Repo.Migrations.CreateArtists do
  use Ecto.Migration

  def change do
    create table(:artists) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :rating, :float
      add :started, :naive_datetime, null: false
      add :ended, :naive_datetime
      add :current_label_id, references(:labels, on_delete: :nothing)

      timestamps()
    end

    create index(:artists, [:slug], unique: true)
    create index(:artists, [:current_label_id])
  end
end
