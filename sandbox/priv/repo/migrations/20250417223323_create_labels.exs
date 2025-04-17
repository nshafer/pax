defmodule Sandbox.Repo.Migrations.CreateLabels do
  use Ecto.Migration

  def change do
    create table(:labels) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :rating, :float
      add :founded, :integer, null: false
      add :accepting_submissions, :boolean, default: false, null: false

      timestamps()
    end

    create index(:labels, [:slug], unique: true)
  end
end
