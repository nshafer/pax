defmodule Sandbox.Library.Artist do
  use Ecto.Schema
  import Ecto.Changeset

  schema "artists" do
    field :name, :string
    field :slug, :string
    field :rating, :float
    field :started, :naive_datetime
    field :ended, :naive_datetime

    belongs_to :current_label, Sandbox.Library.Label

    timestamps()
  end

  @doc false
  def changeset(artist, attrs) do
    artist
    |> cast(attrs, [:name, :rating, :started, :ended, :current_label_id])
    |> validate_required([:name, :started])
    |> assoc_constraint(:current_label)
  end
end
