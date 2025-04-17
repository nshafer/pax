defmodule Sandbox.Library.Album do
  use Ecto.Schema
  import Ecto.Changeset

  schema "albums" do
    field :uuid, Ecto.UUID, autogenerate: true
    field :name, :string
    field :rating, :float
    field :length_sec, :integer

    belongs_to :artist, Sandbox.Library.Artist
    belongs_to :label, Sandbox.Library.Label

    timestamps()
  end

  @doc false
  def changeset(album, attrs) do
    album
    |> cast(attrs, [:name, :rating, :length_sec, :artist_id, :label_id])
    |> validate_required([:name, :length_sec, :artist_id, :label_id])
    |> assoc_constraint(:artist)
    |> assoc_constraint(:label)
  end
end
