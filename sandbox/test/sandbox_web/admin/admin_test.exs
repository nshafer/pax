defmodule SandboxWeb.AdminTest do
  # SandboxWeb.Admin is mounted at /admin with three resources configured three different ways.
  use SandboxWeb.ConnCase, async: true

  alias Sandbox.Library.Album
  alias Sandbox.Library.Artist
  alias Sandbox.Library.Label
  alias Sandbox.Repo

  describe "dashboard" do
    test "links to every resource", %{conn: conn} do
      conn
      |> visit(~p"/admin")
      |> assert_has("title", text: "Dashboard · Pax Admin")
      |> assert_has(".admin-title", text: "Sandbox Admin")
      |> assert_has(".admin-menu a[href='/admin/r/labels']", text: "Labels")
      |> assert_has(".admin-menu a[href='/admin/r/artists']", text: "Artists")
      |> assert_has(".admin-menu a[href='/admin/r/albums']", text: "Albums")
      |> click_link(".admin-menu a", "Labels")
      |> assert_path(~p"/admin/r/labels")
    end

    test "is linked from the app", %{conn: conn} do
      conn
      |> visit(~p"/")
      |> click_link("Admin")
      |> assert_path(~p"/admin")
    end
  end

  describe "labels, with the adapter and fieldsets" do
    test "lists labels by name then newest founded", %{conn: conn} do
      label_fixture(name: "Warp", founded: 1989)
      label_fixture(name: "Sub Pop", founded: 1986, rating: 2.345)
      label_fixture(name: "Sub Pop", slug: "sub-pop-2", founded: 2001)

      conn
      |> visit(~p"/admin/r/labels")
      |> assert_has(".admin-breadcrumbs", text: "Dashboard ❯ Labels")
      |> assert_has("tbody tr:nth-child(1)", text: "2001")
      |> assert_has("tbody tr:nth-child(2)", text: "1986")
      |> assert_has("tbody tr:nth-child(2)", text: "2.35")
      |> assert_has("tbody tr:nth-child(3)", text: "Warp")
      |> assert_has(".pax-index-table-sort-num", text: "2")
      |> refute_has("th", text: "Slug")
    end

    test "shows, edits and creates labels", %{conn: conn} do
      label = label_fixture(name: "Warp", founded: 1989)

      conn
      |> visit(~p"/admin/r/labels")
      |> click_link("td a", "Warp")
      |> assert_path(~p"/admin/r/labels/#{label.id}")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Name Warp Slug warp")
      |> assert_has(".pax-detail-fieldsets-fieldset-heading", text: "Meta")
      |> click_link("Edit")
      |> assert_path(~p"/admin/r/labels/edit/#{label.id}")
      |> fill_in("Name", with: "Warp Records")
      |> click_button("Save")
      |> assert_path(~p"/admin/r/labels/#{label.id}")
      |> assert_has(".pax-show-title", text: "Label #{label.id}")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Name Warp Records")

      assert Repo.get!(Label, label.id).name == "Warp Records"

      conn
      |> visit(~p"/admin/r/labels/new")
      |> assert_has(".pax-new-title", text: "New Label")
      |> fill_in("Name", with: "Ninja Tune")
      |> fill_in("Slug", with: "ninja-tune")
      |> fill_in("Founded", with: "1990")
      |> fill_in("Rating", with: "4")
      |> click_button("Save")
      |> assert_has(".pax-detail-fieldsets-fieldgroup", text: "Name Ninja Tune")

      assert %Label{founded: 1990, rating: 4.0} = Repo.get_by!(Label, slug: "ninja-tune")
    end
  end

  describe "artists, with only an adapter" do
    test "uses every schema field and names artists by id", %{conn: conn} do
      label = label_fixture()
      artist = artist_fixture(name: "Aphex Twin", current_label_id: label.id)

      conn
      |> visit(~p"/admin/r/artists")
      |> assert_has("th", text: "Current Label Id")
      |> assert_has("th", text: "Inserted At")
      |> assert_has("tbody tr td", text: "Aphex Twin")
      |> click_link("td a", "#{artist.id}")
      |> assert_path(~p"/admin/r/artists/#{artist.id}")
      |> assert_has(".pax-show-title", text: "Artist #{artist.id}")
      |> assert_has(".pax-detail-list-item", text: "Slug aphex-twin")
    end

    test "shows the id and timestamps, and requires every other field when editing", %{conn: conn} do
      artist = artist_fixture(name: "Aphex Twin")

      conn
      |> visit(~p"/admin/r/artists/edit/#{artist.id}")
      |> refute_has("input[name='detail[id]']")
      |> refute_has("input[name='detail[inserted_at]']")
      |> assert_has(".pax-detail-list-item", text: "Id #{artist.id}")
      |> fill_in("Name", with: "AFX")
      |> click_button("Save")
      |> assert_path(~p"/admin/r/artists/edit/#{artist.id}")
      |> assert_has(".pax-field-error", text: "can't be blank")

      assert Repo.get!(Artist, artist.id).name == "Aphex Twin"

      label = label_fixture()

      conn
      |> visit(~p"/admin/r/artists/edit/#{artist.id}")
      |> fill_in("Name", with: "AFX")
      |> fill_in("Rating", with: "4")
      |> fill_in("Ended", with: "2020-01-01T00:00")
      |> fill_in("Current Label Id", with: "#{label.id}")
      |> click_button("Save")
      |> assert_path(~p"/admin/r/artists/#{artist.id}")

      assert Repo.get!(Artist, artist.id).name == "AFX"
    end
  end

  describe "albums, with callbacks and custom fields" do
    test "lists albums with their formatted length, sortable by length", %{conn: conn} do
      album_fixture(name: "Syro", length_sec: 3905)
      album_fixture(name: "Drukqs", length_sec: 6001)

      conn
      |> visit(~p"/admin/r/albums")
      |> assert_has("tbody tr:nth-child(1)", text: "Drukqs")
      |> assert_has("tbody tr:nth-child(1)", text: "100:01")
      |> assert_has("tbody tr:nth-child(2)", text: "65:05")
      |> refute_has("th", text: "Label Id")
      |> click_link("th a", "Length")
      |> assert_path(~p"/admin/r/albums", query_params: %{sort: "length_sec"})
      |> assert_has("tbody tr:nth-child(1)", text: "Syro")
    end

    test "shows and edits albums by uuid", %{conn: conn} do
      album = album_fixture(name: "Syro", length_sec: 3905)
      label = label_fixture()

      conn
      |> visit(~p"/admin/r/albums")
      |> click_link("td a", "Syro")
      |> assert_path(~p"/admin/r/albums/#{album.uuid}")
      |> assert_has(".pax-show-title", text: "Syro")
      |> assert_has(".admin-breadcrumbs", text: "Albums ❯ Syro")
      |> assert_has(".pax-detail-list-item", text: "Uuid #{album.uuid}")
      |> assert_has(".pax-detail-list-item", text: "Length 65:05")
      |> click_link("Edit")
      |> assert_path(~p"/admin/r/albums/edit/#{album.uuid}")
      |> fill_in("Length (seconds)", with: "4000")
      |> fill_in("Label Id", with: "#{label.id}")
      |> click_button("Save")
      |> assert_path(~p"/admin/r/albums/#{album.uuid}")
      |> assert_has(".pax-detail-list-item", text: "Length 66:40")

      assert %Album{length_sec: 4000} = Repo.get!(Album, album.id)
    end
  end

  test "Pax assets are served by the endpoint", %{conn: conn} do
    conn = get(conn, "/pax/assets/pax.css")
    assert response_content_type(conn, :css) =~ "text/css"

    conn = get(build_conn(), "/pax/admin/assets/pax_admin.js")
    assert response(conn, 200) =~ "phoenix_live_view"
  end
end
