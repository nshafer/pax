defmodule SandboxWeb.AshAdminTest do
  # The same three tables as SandboxWeb.AdminTest, but through Pax.Adapters.Ash, mounted under /admin/ash.
  use SandboxWeb.ConnCase, async: true

  alias Sandbox.Catalog
  alias Sandbox.Repo

  describe "dashboard" do
    test "lists the Ash section beside the Ecto one", %{conn: conn} do
      conn
      |> visit(~p"/admin")
      |> assert_has(".admin-menu a[href='/admin/r/albums']", text: "Albums")
      |> assert_has(".admin-menu a[href='/admin/ash/r/albums']", text: "Albums")
      |> click_link(".admin-menu a[href='/admin/ash/r/labels']", "Labels")
      |> assert_path(~p"/admin/ash/r/labels")
    end
  end

  describe "labels, read only through the Ash adapter" do
    test "lists and sorts them", %{conn: conn} do
      label_fixture(%{name: "Aardvark Records", founded: 1950})
      label_fixture(%{name: "Zebra Sounds", founded: 1990})

      conn
      |> visit(~p"/admin/ash/r/labels")
      |> assert_has(".pax-index-title", text: "Labels")
      |> assert_has("tbody tr:nth-child(1)", text: "Aardvark Records")
      |> click_link("th a", "Founded")
      |> assert_path(~p"/admin/ash/r/labels", query_params: %{sort: "founded"})
    end

    test "shows one, using the configured object name", %{conn: conn} do
      label = label_fixture(%{name: "Harmonic Records"})

      conn
      |> visit(~p"/admin/ash/r/labels/#{label.id}")
      |> assert_has(".pax-show-title", text: "Harmonic Records")
      |> assert_has(".pax-detail-list-field-text", text: label.slug)
    end
  end

  describe "artists, configured by introspection alone" do
    test "lists them with fields the adapter found on the resource", %{conn: conn} do
      artist_fixture(%{name: "Octavia"})

      conn
      |> visit(~p"/admin/ash/r/artists")
      |> assert_has(".pax-index-title", text: "Artists")
      |> assert_has("th", text: "Name")
      |> assert_has("th", text: "Started")
      |> assert_has("tbody tr", text: "Octavia")
    end

    test "edits one through an AshPhoenix form", %{conn: conn} do
      artist = artist_fixture(%{name: "Ursula"})

      conn
      |> visit(~p"/admin/ash/r/artists/edit/#{artist.id}")
      |> assert_has(".pax-edit-title", text: "Edit")
      |> fill_in("Name", with: "Ursula K. Le Guin")
      |> click_button("Save")
      |> assert_path(~p"/admin/ash/r/artists/#{artist.id}")

      assert Repo.get!(Sandbox.Library.Artist, artist.id).name == "Ursula K. Le Guin"
    end

    test "shows the form's errors without saving", %{conn: conn} do
      artist = artist_fixture(%{name: "Ursula"})

      conn
      |> visit(~p"/admin/ash/r/artists/edit/#{artist.id}")
      |> fill_in("Name", with: "")
      |> click_button("Save")
      |> assert_path(~p"/admin/ash/r/artists/edit/#{artist.id}")
      |> assert_has(".pax-field-error")

      assert Repo.get!(Sandbox.Library.Artist, artist.id).name == "Ursula"
    end

    test "creates one", %{conn: conn} do
      conn
      |> visit(~p"/admin/ash/r/artists/new")
      |> fill_in("Name", with: "Octavia")
      |> fill_in("Slug", with: "octavia-#{System.unique_integer([:positive])}")
      |> fill_in("Started", with: "2001-01-01T00:00")
      |> click_button("Save")
      |> assert_has(".pax-show-title")

      assert Repo.get_by!(Sandbox.Library.Artist, name: "Octavia")
    end
  end

  describe "albums, which are forbid-by-default" do
    test "render for an actor the policy allows", %{conn: conn} do
      album_fixture(%{name: "Dune"})

      conn
      |> visit(~p"/admin/ash/r/albums")
      |> assert_has(".pax-index-title", text: "Albums")
      |> assert_has("tbody tr", text: "Dune")
    end

    test "are refused outright when there is no actor at all", %{conn: conn} do
      album_fixture(%{name: "Dune"})

      # Ash refuses the read rather than answering an empty page, because the policy references the actor.
      assert_raise Ash.Error.Forbidden, fn -> visit(conn, ~p"/admin/ash/r/albums?actor=none") end
    end

    test "are refused for an actor the policy does not allow", %{conn: conn} do
      album_fixture(%{name: "Dune"})

      assert_raise Ash.Error.Forbidden, fn -> visit(conn, ~p"/admin/ash/r/albums?actor=guest") end
    end

    test "edits one, with the actor resolved on every call", %{conn: conn} do
      album = album_fixture(%{name: "Dune"})

      conn
      |> visit(~p"/admin/ash/r/albums/edit/#{album.id}")
      |> fill_in("Name", with: "Dune Messiah")
      |> click_button("Save")
      |> assert_path(~p"/admin/ash/r/albums/#{album.id}")

      assert Repo.get!(Sandbox.Library.Album, album.id).name == "Dune Messiah"
    end

    test "shows the same row as the Ecto-backed resource", %{conn: conn} do
      album = album_fixture(%{name: "Shared Row"})

      conn |> visit(~p"/admin/r/albums/#{album.uuid}") |> assert_has(".pax-show-title", text: "Shared Row")
      conn |> visit(~p"/admin/ash/r/albums/#{album.id}") |> assert_has(".pax-show-title", text: "Shared Row")
    end
  end

  describe "the Ash resources and the Ecto context" do
    test "see the same rows, since they are the same tables", %{conn: _conn} do
      label_fixture(%{name: "Both Ways"})

      assert Ash.count!(Catalog.Label, authorize?: false) == length(Sandbox.Library.list_labels())
    end
  end
end
