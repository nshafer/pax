defmodule Sandbox.LibraryFixtures do
  @moduledoc """
  Test helpers for creating entities in the `Sandbox.Library` context.

  Slugs aren't cast by the schema changesets, so these insert structs directly, like the seeds do.
  """

  alias Sandbox.Library.Album
  alias Sandbox.Library.Artist
  alias Sandbox.Library.Label
  alias Sandbox.Repo

  def label_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    name = Map.get(attrs, :name, "Label #{System.unique_integer([:positive])}")

    %Label{
      name: name,
      slug: slugify(name),
      founded: 1990,
      rating: nil,
      accepting_submissions: false
    }
    |> struct!(attrs)
    |> Repo.insert!()
  end

  def artist_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    name = Map.get(attrs, :name, "Artist #{System.unique_integer([:positive])}")

    %Artist{
      name: name,
      slug: slugify(name),
      started: ~N[2000-01-01 00:00:00]
    }
    |> struct!(attrs)
    |> Repo.insert!()
  end

  def album_fixture(attrs \\ %{}) do
    attrs = Map.new(attrs)
    artist_id = Map.get_lazy(attrs, :artist_id, fn -> artist_fixture().id end)

    %Album{
      name: "Album #{System.unique_integer([:positive])}",
      length_sec: 2400,
      artist_id: artist_id
    }
    |> struct!(attrs)
    |> Repo.insert!()
  end

  defp slugify(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
