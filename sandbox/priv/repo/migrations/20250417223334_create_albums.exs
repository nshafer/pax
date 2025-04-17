defmodule Sandbox.Repo.Migrations.CreateAlbums do
  use Ecto.Migration

  def change do
    create table(:albums) do
      add :uuid, :uuid
      add :name, :string, null: false
      add :rating, :float
      add :length_sec, :integer, null: false
      add :artist_id, references(:artists, on_delete: :nothing), null: false
      add :label_id, references(:labels, on_delete: :nothing)

      timestamps()
    end

    create index(:albums, [:uuid], unique: true)
    create index(:albums, [:artist_id])
    create index(:albums, [:label_id])
  end
end
