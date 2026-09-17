defmodule SandboxWeb.AlbumLiveTest do
  # AlbumLive has no adapter. It implements every data callback with the Sandbox.Library context, and looks albums up
  # by UUID.
  use SandboxWeb.ConnCase, async: true

  alias Sandbox.Library.Album
  alias Sandbox.Repo

  describe "index" do
    test "lists albums by name, with links by uuid", %{conn: conn} do
      artist = artist_fixture()
      album = album_fixture(name: "Selected Ambient Works", artist_id: artist.id, rating: 4.8765, length_sec: 4500)
      album_fixture(name: "Drukqs", artist_id: artist.id)

      conn
      |> visit(~p"/albums")
      |> assert_has(".pax-index-title", text: "Albums")
      |> assert_has("tbody tr:nth-child(1)", text: "Drukqs")
      |> assert_has("tbody tr:nth-child(2)", text: "Selected Ambient Works")
      |> assert_has("tbody tr:nth-child(2) td", text: "4.877")
      |> assert_has("tbody tr:nth-child(2) td", text: "4500")
      |> assert_has("tbody tr:nth-child(2) td a[href='#{~p"/albums/#{album.uuid}"}']")
    end

    test "sorts and paginates through the context", %{conn: conn} do
      artist = artist_fixture()
      for i <- 1..11, do: album_fixture(name: "Album #{i}", artist_id: artist.id, length_sec: 1000 - i)

      conn
      |> visit(~p"/albums")
      |> click_link("th a", "Length Sec")
      |> assert_has("tbody tr", count: 10)
      |> assert_has("tbody tr:nth-child(1)", text: "Album 11")
      |> assert_has(".pax-footer", text: "Page: 1 / 2")
      |> visit(~p"/albums?page=2&sort=length_sec")
      |> assert_has("tbody tr", count: 1)
      |> assert_has("tbody tr", text: "Album 1")
    end
  end

  describe "show" do
    test "shows the album", %{conn: conn} do
      album = album_fixture(name: "Drukqs")

      conn
      |> visit(~p"/albums/#{album.uuid}")
      |> assert_has(".pax-show-title", text: "Drukqs")
      |> assert_has(".pax-detail-fieldsets-field", text: "Uuid #{album.uuid}")
      |> assert_has(".pax-detail-fieldsets-field", text: "Artist Id #{album.artist_id}")
    end
  end

  describe "edit" do
    test "updates the album", %{conn: conn} do
      album = album_fixture(name: "Drukqs")
      label = label_fixture()

      conn
      |> visit(~p"/albums/#{album.uuid}/edit")
      |> refute_has("input[name='detail[uuid]']")
      |> fill_in("Name", with: "Drukqs (Remastered)")
      |> fill_in("Rating", with: "4.5")
      |> fill_in("Label Id", with: "#{label.id}")
      |> click_button("Save")
      |> assert_path(~p"/albums/#{album.uuid}")
      |> assert_has("#flash-info", text: "Updated successfully.")

      assert %Album{name: "Drukqs (Remastered)", rating: 4.5, label_id: label_id} = Repo.get!(Album, album.id)
      assert label_id == label.id
    end

    test "doesn't save when the context's changeset has errors", %{conn: conn} do
      album = album_fixture(name: "Drukqs")

      # The assoc_constraint error is on :label, which isn't a field on the page, so it isn't shown (see docs/todo.md)
      conn
      |> visit(~p"/albums/#{album.uuid}/edit")
      |> fill_in("Name", with: "Changed")
      |> fill_in("Label Id", with: "0")
      |> click_button("Save")
      |> assert_path(~p"/albums/#{album.uuid}/edit")
      |> refute_has("#flash-info")

      assert Repo.get!(Album, album.id).name == "Drukqs"
    end
  end

  describe "new" do
    test "creates an album", %{conn: conn} do
      artist = artist_fixture()
      label = label_fixture()

      conn
      |> visit(~p"/albums")
      |> click_link("New Album")
      |> fill_in("Name", with: "Syro")
      |> fill_in("Artist Id", with: "#{artist.id}")
      |> fill_in("Length Sec", with: "3900")
      |> fill_in("Label Id", with: "#{label.id}")
      |> click_button("Save")
      |> assert_has("#flash-info", text: "Created successfully.")
      |> assert_has(".pax-show-title", text: "Syro")

      assert %Album{uuid: uuid, length_sec: 3900} = Repo.get_by!(Album, name: "Syro")
      assert uuid
    end

    test "shows validation errors", %{conn: conn} do
      conn
      |> visit(~p"/albums/new")
      |> fill_in("Name", with: "Syro")
      |> click_button("Save")
      |> assert_path(~p"/albums/new")
      |> assert_has(".pax-field-error", text: "can't be blank")

      refute Repo.get_by(Album, name: "Syro")
    end
  end
end
