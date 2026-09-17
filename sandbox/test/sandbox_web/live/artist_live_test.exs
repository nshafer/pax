defmodule SandboxWeb.ArtistLiveTest do
  # ArtistLive uses the EctoSchema adapter, looks artists up by slug, and lays out detail pages with fieldsets.
  use SandboxWeb.ConnCase, async: true

  alias Sandbox.Library.Artist
  alias Sandbox.Repo

  describe "index" do
    test "lists the highest rated artists first, then by name", %{conn: conn} do
      label = label_fixture(name: "Warp")
      artist_fixture(name: "Unrated")
      artist_fixture(name: "Aphex Twin", rating: 4.5, current_label_id: label.id)
      artist_fixture(name: "Boards of Canada", rating: 4.9)
      artist_fixture(name: "Autechre")

      conn
      |> visit(~p"/artists")
      |> assert_has("tbody tr:nth-child(1)", text: "Boards of Canada")
      |> assert_has("tbody tr:nth-child(1)", text: "4.9")
      |> assert_has("tbody tr:nth-child(2)", text: "Aphex Twin")
      |> assert_has("tbody tr:nth-child(2)", text: "#{label.id}")
      |> assert_has("tbody tr:nth-child(3)", text: "Autechre")
      |> assert_has("tbody tr:nth-child(3) td", text: "-")
      |> assert_has("tbody tr:nth-child(4)", text: "Unrated")
      |> refute_has("th", text: "Started")
    end

    test "links to each artist by slug", %{conn: conn} do
      artist_fixture(name: "Aphex Twin")

      conn
      |> visit(~p"/artists")
      |> click_link("td a", "Aphex Twin")
      |> assert_path(~p"/artists/aphex-twin")
    end
  end

  describe "show" do
    test "shows the artist in fieldsets", %{conn: conn} do
      artist = artist_fixture(name: "Aphex Twin", rating: 4.5, started: ~N[1985-06-01 12:30:00])

      conn
      |> visit(~p"/artists/aphex-twin")
      |> assert_has(".pax-show-title", text: "Aphex Twin")
      |> assert_has(".pax-breadcrumbs a", text: "Artists")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Name Aphex Twin Slug aphex-twin")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Rating 4.5")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Started Sat, June 01, 1985 12:30 PM")
      |> assert_has(".pax-detail-fieldsets-fieldset-heading", text: "Metadata")
      |> assert_has(".pax-detail-fieldsets-fieldset", text: "Id #{artist.id}")
    end
  end

  describe "edit" do
    test "updates the artist, following a changed slug", %{conn: conn} do
      artist = artist_fixture(name: "Aphex Twin", rating: 4.5)

      conn
      |> visit(~p"/artists/aphex-twin")
      |> click_link("Edit")
      |> assert_path(~p"/artists/aphex-twin/edit")
      |> fill_in("Name", with: "AFX")
      |> fill_in("Slug", with: "afx")
      |> fill_in("Rating", with: "3.25")
      |> fill_in("Started", with: "1991-02-03T04:05")
      |> click_button("Save")
      |> assert_path(~p"/artists/afx")
      |> assert_has(".pax-show-title", text: "AFX")

      assert %Artist{name: "AFX", slug: "afx", rating: 3.25, started: ~N[1991-02-03 04:05:00]} =
               Repo.get!(Artist, artist.id)
    end

    test "requires a start date but not an end date or label", %{conn: conn} do
      artist_fixture(name: "Aphex Twin", rating: 4.5)

      session =
        conn
        |> visit(~p"/artists/aphex-twin/edit")
        |> fill_in("Started", with: "")
        |> click_button("Save")

      assert_has(session, ".pax-detail-fieldsets-field", text: "Started can't be blank")
      refute_has(session, ".pax-detail-fieldsets-field", text: "Ended can't be blank")
    end
  end

  describe "new" do
    test "creates an artist", %{conn: conn} do
      conn
      |> visit(~p"/artists")
      |> click_link("New Artist")
      |> fill_in("Name", with: "Autechre")
      |> fill_in("Slug", with: "autechre")
      |> fill_in("Started", with: "1987-01-01T00:00")
      |> click_button("Save")
      |> assert_path(~p"/artists/autechre")
      |> assert_has("#flash-info", text: "Created successfully.")

      assert %Artist{name: "Autechre", ended: nil} = Repo.get_by!(Artist, slug: "autechre")
    end
  end
end
