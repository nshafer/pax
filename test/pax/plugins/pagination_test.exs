defmodule Pax.Plugins.PaginationTest do
  use PaxTest.ConnCase, async: true

  import Phoenix.LiveViewTest,
    only: [live: 2, element: 2, render_change: 2, render_submit: 2, render_click: 3, assert_patch: 2, has_element?: 2]

  import PaxTest.HTML, only: [texts: 2, attr: 3, count: 2, classes: 2]

  alias Pax.Plugins.Pagination

  defp books(count), do: for(id <- 1..count//1, do: %{id: id, title: "Book #{id}"})

  defp books_interface(count, plugin \\ Pax.Plugins.Pagination, config \\ []) do
    interface(
      pax_plugins: [Pax.Plugins.IndexTable, plugin],
      pax_config: Keyword.merge([fields: [{:title, :string}]], config),
      count_objects: count,
      list_objects: fn criteria, _socket ->
        Owner.notify({:criteria, criteria})
        books(count) |> Enum.drop(criteria.offset) |> Enum.take(criteria.limit)
      end
    )
  end

  defp received_criteria do
    assert {:criteria, criteria} = last_received({:criteria, _})
    Map.take(criteria, [:limit, :offset])
  end

  defp pager_links(session), do: attr(html(session), "a.pax-pagination-link", "href")
  defp pager_classes(session), do: classes(html(session), "a.pax-pagination-link")

  test "has a valid config spec and documented options" do
    assert {:ok, _} = Pax.Config.validate(Pagination.config_spec(), %{}, validate_config_spec: true)

    assert_raise ArgumentError, ~r/^Invalid options for plugin .*Pagination: unknown options \[:nope\]/, fn ->
      PaxTest.PluginHelpers.plugin(Pagination, nope: true)
    end

    assert {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(Pagination)
    assert moduledoc =~ "## Options"
  end

  describe "pages" do
    test "limits the objects to the first page by default", %{conn: conn} do
      books_interface(25)

      session = visit(conn, "/interface")

      assert received_criteria() == %{limit: 10, offset: 0}
      assert texts(html(session), ".pax-footer-primary > div") == ["Page: 1 / 3", "Total: 25"]
      assert count(html(session), "tbody tr") == 10

      assert pager_links(session) == ["/interface", "/interface", "/interface?page=2", "/interface?page=3"]
      assert attr(html(session), "form", "id") == ["pax-pagination-form"]

      assert pager_classes(session) == [
               "pax-link pax-pagination-link disabled",
               "pax-link pax-pagination-link disabled",
               "pax-link pax-pagination-link",
               "pax-link pax-pagination-link"
             ]

      assert texts(html(session), "select.pax-pagination-page-select option") == ["1", "2", "3"]
      assert attr(html(session), "select option[selected]", "value") == ["1"]
    end

    test "offsets the objects by the page param", %{conn: conn} do
      books_interface(25)

      session = visit(conn, "/interface?page=2&sort=title")

      assert received_criteria() == %{limit: 10, offset: 10}
      assert texts(html(session), ".pax-footer-primary > div") == ["Page: 2 / 3", "Total: 25"]

      assert pager_links(session) == [
               "/interface?sort=title",
               "/interface?sort=title",
               "/interface?page=3&sort=title",
               "/interface?page=3&sort=title"
             ]

      assert pager_classes(session) |> Enum.all?(&(not String.contains?(&1, "disabled")))

      session = visit(conn, "/interface?page=3")

      assert received_criteria() == %{limit: 10, offset: 20}
      assert count(html(session), "tbody tr") == 5
      assert pager_links(session) == ["/interface", "/interface?page=2", "/interface?page=3", "/interface?page=3"]
      assert pager_classes(session) |> Enum.drop(2) |> Enum.all?(&String.contains?(&1, "disabled"))
    end

    test "falls back to the first page for invalid page params", %{conn: conn} do
      books_interface(25)

      for page <- ["abc", "0", "-2", "2x"] do
        visit(conn, "/interface?page=#{page}")
        assert received_criteria() == %{limit: 10, offset: 0}
      end
    end

    test "requires a positive number of objects per page" do
      assert_raise ArgumentError,
                   ~r/^Invalid options for plugin Pax.Plugins.Pagination: invalid value for :objects_per_page/,
                   fn ->
                     PaxTest.PluginHelpers.plugin(Pagination, objects_per_page: 0)
                   end
    end

    test "can change the objects per page", %{conn: conn} do
      books_interface(25, {Pax.Plugins.Pagination, objects_per_page: 5})
      visit(conn, "/interface?page=2")
      assert received_criteria() == %{limit: 5, offset: 5}

      books_interface(25, Pax.Plugins.Pagination, plugins: [pagination: [objects_per_page: fn _ -> 20 end]])
      session = visit(conn, "/interface")
      assert received_criteria() == %{limit: 20, offset: 0}
      assert texts(html(session), ".pax-footer-primary > div") == ["Page: 1 / 2", "Total: 25"]
    end

    test "uses a number input instead of a select with more than 10 pages", %{conn: conn} do
      books_interface(25, {Pax.Plugins.Pagination, objects_per_page: 2})

      session = visit(conn, "/interface?page=4")

      assert count(html(session), "select") == 0
      assert attr(html(session), "input.pax-pagination-page-input", "value") == ["4"]
      assert attr(html(session), "input.pax-pagination-page-input", "inputmode") == ["numeric"]
    end

    test "disables the select with a single page", %{conn: conn} do
      books_interface(3)

      session = visit(conn, "/interface")

      assert attr(html(session), "select", "disabled") == [""]
      assert pager_classes(session) |> Enum.all?(&String.contains?(&1, "disabled"))
    end

    test "shows a single page with no objects", %{conn: conn} do
      books_interface(0)

      session = visit(conn, "/interface")

      assert texts(html(session), ".pax-footer-primary > div") == ["Page: 1 / 1", "Total: 0"]
      assert texts(html(session), "select option") == ["1"]
    end

    test "can be placed in other sections", %{conn: conn} do
      config = [
        plugins: [pagination: [count_placement: :index_header_tertiary, pager_placement: fn _ -> :index_body end]]
      ]

      books_interface(25, Pax.Plugins.Pagination, config)

      conn
      |> visit("/interface")
      |> assert_has(".pax-header-tertiary", text: "Total: 25")
      |> assert_has(".pax-index-body nav.pax-pagination")
      |> refute_has(".pax-footer-secondary nav")
    end

    test "does nothing outside of the index", %{conn: conn} do
      interface(
        pax_plugins: [Pax.Plugins.Pagination, PaxTest.SpyPlugin],
        pax_config: [fields: [{:name, :string}]],
        get_object: %{id: 1, name: "Ursula"}
      )

      conn
      |> visit("/interface/1")
      |> refute_has("nav.pax-pagination")

      assert {:spy, :after_params, pax} = last_received({:spy, :after_params, _})
      refute Map.has_key?(pax.private, :pagination)
      refute Map.has_key?(pax.criteria, :limit)
    end
  end

  describe "page events" do
    test "changing the page patches to it", %{conn: conn} do
      books_interface(25)
      {:ok, view, _html} = live(conn, "/interface?sort=title")

      view |> element("form") |> render_change(%{"page" => "2"})
      assert_patch(view, "/interface?page=2&sort=title")

      view |> element("form") |> render_change(%{"page" => "1"})
      assert_patch(view, "/interface?sort=title")

      view |> element("form") |> render_submit(%{"page" => "3"})
      assert_patch(view, "/interface?page=3&sort=title")
    end

    test "invalid pages show an error", %{conn: conn} do
      books_interface(25)
      {:ok, view, _html} = live(conn, "/interface")

      for page <- ["0", "4", "x"] do
        view |> element("form") |> render_change(%{"page" => page})
        assert has_element?(view, "select.pax-pagination-page-select.has-errors")

        view |> element("form") |> render_submit(%{"page" => "1"})
        refute has_element?(view, "select.has-errors")
      end

      view |> element("form") |> render_submit(%{"page" => "9"})
      assert has_element?(view, "select.has-errors")
    end

    test "other events are passed along", %{conn: conn} do
      books_interface(25)
      {:ok, view, _html} = live(conn, "/interface")

      render_click(view, "custom", %{})
      assert_receive {:user_handle_event, "custom", %{}}
    end
  end
end
