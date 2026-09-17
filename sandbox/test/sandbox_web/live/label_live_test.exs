defmodule SandboxWeb.LabelLiveTest do
  # LabelLive uses the EctoSchema adapter for all data access, with DetailList for its detail pages.
  use SandboxWeb.ConnCase, async: true

  alias Sandbox.Library.Label
  alias Sandbox.Repo

  describe "index" do
    test "lists labels ordered by name", %{conn: conn} do
      label_fixture(name: "Warp", founded: 1989, rating: 4.25, accepting_submissions: true)
      label_fixture(name: "Sub Pop", founded: 1986)

      conn
      |> visit(~p"/labels")
      |> assert_has(".pax-index-title", text: "Labels")
      |> assert_has("th", text: "Name Link")
      |> assert_has("tbody tr:nth-child(1) td", text: "Sub Pop")
      |> assert_has("tbody tr:nth-child(1) td", text: "1986")
      |> assert_has("tbody tr:nth-child(1) td", text: "No")
      |> assert_has("tbody tr:nth-child(1) td", text: "-")
      |> assert_has("tbody tr:nth-child(2) td", text: "Warp")
      |> assert_has("tbody tr:nth-child(2) td", text: "Yes")
      |> assert_has("tbody tr:nth-child(2) td", text: "4.25")
      |> refute_has("th", text: "Slug")
    end

    test "paginates 10 labels at a time", %{conn: conn} do
      for i <- 1..12, do: label_fixture(name: "Label #{String.pad_leading("#{i}", 2, "0")}")

      conn
      |> visit(~p"/labels")
      |> assert_has(".pax-index-footer", text: "Page: 1 / 2")
      |> assert_has(".pax-index-footer", text: "Total: 12")
      |> assert_has("tbody tr", count: 10)
      |> refute_has("td", text: "Label 11")
      |> visit(~p"/labels?page=2")
      |> assert_has("tbody tr", count: 2)
      |> assert_has("td", text: "Label 12")
    end

    test "sorts by clicking the column headers", %{conn: conn} do
      label_fixture(name: "Old", founded: 1950, rating: 1.0)
      label_fixture(name: "New", founded: 2020)
      label_fixture(name: "Middle", founded: 1990, rating: 3.0)

      conn
      |> visit(~p"/labels")
      |> click_link("th a", "Founded")
      |> assert_path(~p"/labels", query_params: %{sort: "founded"})
      |> assert_has("tbody tr:nth-child(1)", text: "Old")
      |> assert_has("tbody tr:nth-child(3)", text: "New")
      |> click_link("th a", "Founded")
      |> assert_path(~p"/labels", query_params: %{sort: "-founded"})
      |> assert_has("tbody tr:nth-child(1)", text: "New")
      |> click_link("th a", "Rating Formatted")
      |> assert_path(~p"/labels", query_params: %{sort: "~rating"})
      |> assert_has("tbody tr:nth-child(1)", text: "New")
      |> assert_has("tbody tr:nth-child(2)", text: "Old")
    end

    test "can still handle the LiveView's own events", %{conn: conn} do
      conn
      |> visit(~p"/labels")
      |> assert_has("main", text: "Counter: 0")
      |> click_button("Increment")
      |> assert_has("main", text: "Counter: 1")
      |> click_button("Append title")
      |> assert_has(".pax-index-title", text: "Labels.")
    end
  end

  describe "show" do
    test "shows the label, with a link back to the index page it came from", %{conn: conn} do
      label = label_fixture(name: "Warp", founded: 1989)
      for i <- 1..10, do: label_fixture(name: "A Label #{i}")

      conn
      |> visit(~p"/labels?page=2")
      |> click_link("td a", "Warp")
      |> assert_path(~p"/labels/#{label}")
      |> assert_has(".pax-show-title", text: "Warp")
      |> assert_has(".pax-detail-list-item", text: "Slug warp")
      |> assert_has(".pax-detail-list-item", text: "Founded 1989")
      |> assert_has(".pax-detail-list-item", text: "Accepting Submissions No")
      |> click_link(".pax-breadcrumbs a", "Labels")
      |> assert_path(~p"/labels", query_params: %{page: "2"})
    end

    test "raises for labels that don't exist", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn -> visit(conn, ~p"/labels/0") end
    end
  end

  describe "edit" do
    test "updates the label", %{conn: conn} do
      label = label_fixture(name: "Warp", founded: 1989)

      conn
      |> visit(~p"/labels/#{label}")
      |> click_link("Edit")
      |> assert_path(~p"/labels/#{label}/edit")
      |> assert_has(".pax-edit-title", text: "Edit: Warp")
      |> fill_in("Name", with: "Warp Records")
      |> fill_in("Founded", with: "1990")
      |> fill_in("Rating (0-5)", with: "4.5")
      |> check("Accepting Submissions")
      |> click_button("Save")
      |> assert_path(~p"/labels/#{label}")
      |> assert_has("#flash-info", text: "Updated successfully.")
      |> assert_has(".pax-show-title", text: "Warp Records")

      assert %Label{name: "Warp Records", founded: 1990, rating: 4.5, accepting_submissions: true} =
               Repo.get!(Label, label.id)
    end

    test "shows validation errors", %{conn: conn} do
      label = label_fixture(name: "Warp")

      conn
      |> visit(~p"/labels/#{label}/edit")
      |> fill_in("Name", with: "")
      |> assert_has(".pax-field-error", text: "can't be blank")
      |> click_button("Save")
      |> assert_path(~p"/labels/#{label}/edit")
      |> assert_has(".pax-field-error", text: "can't be blank")

      assert Repo.get!(Label, label.id).name == "Warp"
    end

    test "cancel goes back to the label", %{conn: conn} do
      label = label_fixture()

      conn
      |> visit(~p"/labels/#{label}/edit")
      |> click_link("Cancel")
      |> assert_path(~p"/labels/#{label}")
    end
  end

  describe "new" do
    test "creates a label", %{conn: conn} do
      conn
      |> visit(~p"/labels")
      |> click_link("New Label")
      |> assert_path(~p"/labels/new")
      |> assert_has(".pax-new-title", text: "New Label")
      |> fill_in("Name", with: "Stones Throw")
      |> fill_in("Slug", with: "stones-throw")
      |> fill_in("Founded", with: "1996")
      |> check("Accepting Submissions")
      |> click_button("Save")
      |> assert_has("#flash-info", text: "Created successfully.")
      |> assert_has(".pax-show-title", text: "Stones Throw")

      assert %Label{founded: 1996, accepting_submissions: true} = label = Repo.get_by!(Label, slug: "stones-throw")

      conn
      |> visit(~p"/labels")
      |> assert_has("td a[href='#{~p"/labels/#{label}"}']", text: "Stones Throw")
    end

    test "shows validation errors", %{conn: conn} do
      conn
      |> visit(~p"/labels/new")
      |> fill_in("Name", with: "No Slug")
      |> click_button("Save")
      |> assert_path(~p"/labels/new")
      |> assert_has(".pax-field-error", text: "can't be blank")

      refute Repo.get_by(Label, name: "No Slug")
    end
  end
end
