defmodule Pax.Plugins.IndexTableTest do
  use PaxTest.ConnCase, async: true

  import PaxTest.HTML, only: [texts: 2, attr: 3, count: 2]
  import PaxTest.PluginHelpers
  alias Pax.Plugins.IndexTable

  @moduletag :capture_log

  @books [
    %{id: 1, title: "Dune", rank: 2, rating: 4.5, page_count: 412},
    %{id: 2, title: "Emma", rank: nil, rating: 4.0, page_count: 474}
  ]

  @fields [
    {:title, :string, sort: true},
    {:rank, :integer, sort: true, sort_asc: :asc_nulls_first, sort_desc: :desc_nulls_last},
    {:rating, :float},
    {:pages, :integer, value: :page_count, sort: :page_count}
  ]

  defp books_interface(config \\ [], plugins \\ [Pax.Plugins.IndexTable]) do
    interface(
      pax_plugins: plugins,
      pax_config: Keyword.merge([fields: @fields, show_path: fn o, _ -> "/interface/#{o.id}" end], config),
      count_objects: 2,
      list_objects: fn criteria, _socket ->
        Owner.notify({:criteria, criteria})
        @books
      end
    )
  end

  defp received_order_by do
    assert {:criteria, criteria} = last_received({:criteria, _})
    Map.get(criteria, :order_by)
  end

  test "has a valid config spec" do
    assert {:ok, _} = Pax.Config.validate(IndexTable.config_spec(), %{}, validate_config_spec: true)
  end

  describe "rendering" do
    test "renders a header for each field, linking the sortable ones", %{conn: conn} do
      books_interface()

      session = visit(conn, "/interface")

      assert texts(html(session), "th") == ["Title", "Rank", "Rating", "Pages"]

      assert attr(html(session), "th a.pax-index-table-header-link", "href") == [
               "/interface?sort=title",
               "/interface?sort=~rank",
               "/interface?sort=page_count"
             ]

      assert texts(html(session), "th .pax-index-table-header-label") == ["Rating"]
      assert count(html(session), ".pax-index-table-header-sort") == 0
    end

    test "renders a row for each object, linking with the index query", %{conn: conn} do
      books_interface()

      conn
      |> visit("/interface?page=2")
      |> assert_has("tr#pax-object-1 td a[href='/interface/1?index_query=page%253D2']", text: "Dune")
      |> assert_has("tr#pax-object-1 td .pax-index-table-datacell-text", text: "412")
      |> assert_has("tr#pax-object-2 td .pax-index-table-datacell-text", text: "•")
    end

    test "only renders the configured fields, in order", %{conn: conn} do
      books_interface(plugins: [index_table: [fields: [:rating, :missing, :title]]])

      session = visit(conn, "/interface")
      assert texts(html(session), "th") == ["Rating", "Title"]
      assert texts(html(session), "tr#pax-object-1 td") == ["4.5", "Dune"]
    end

    test "can be placed in another section", %{conn: conn} do
      books_interface(plugins: [index_table: [placement: fn _ -> :index_footer_primary end]])

      conn
      |> visit("/interface")
      |> assert_has(".pax-footer-primary .pax-index-table")
      |> refute_has(".pax-index-body .pax-index-table")
    end

    test "renders without sort state from handle_params" do
      pax = %Pax.Interface{
        action: :index,
        fields: [Pax.Field.init(nil, {:title, :string})],
        objects: [{"pax-object-1", %{title: "Dune"}}],
        path: %URI{path: "/"}
      }

      html = render_plugin(plugin(IndexTable), :index_body, pax)

      assert PaxTest.HTML.texts(html, "td") == ["Dune"]
      assert count(html, ".pax-index-table-header-sort") == 0
    end

    test "only renders on the index" do
      pax = %Pax.Interface{action: :show, fields: [Pax.Field.init(nil, {:title, :string})]}
      assert render_plugin(plugin(IndexTable), :index_body, pax) == ""
    end

    test "raises on invalid field names" do
      pax = %Pax.Interface{action: :index, fields: [Pax.Field.init(nil, {:title, :string})], objects: []}

      assert_raise RuntimeError, ~r/Invalid field:\n\n"title"/, fn ->
        render_plugin(plugin(IndexTable, [], fields: ["title"]), :index_body, pax)
      end
    end
  end

  describe "sorting with the sort param" do
    test "sorts by a field in each direction", %{conn: conn} do
      books_interface()

      for {param, order_by} <- [
            {"title", [asc: :title]},
            {"-title", [desc: :title]},
            {"~rank", [asc_nulls_first: :rank]},
            {".rank", [asc_nulls_last: :rank]},
            {"-~rank", [desc_nulls_first: :rank]},
            {"-.rank", [desc_nulls_last: :rank]},
            {"page_count", [asc: :page_count]}
          ] do
        visit(conn, "/interface?sort=#{URI.encode_www_form(param)}")
        assert received_order_by() == order_by
      end
    end

    test "sorts by multiple fields", %{conn: conn} do
      books_interface()

      session = visit(conn, "/interface?sort[]=-rank&sort[]=title")
      assert received_order_by() == [desc: :rank, asc: :title]

      assert texts(html(session), ".pax-index-table-sort-num") == ["2", "1"]
      assert attr(html(session), ".pax-index-table-sort-num", "title") == ["Sort number: 2", "Sort number: 1"]
    end

    test "ignores unknown and unsortable fields", %{conn: conn} do
      books_interface(default_criteria: [limit: 1])

      visit(conn, "/interface?sort=not_an_existing_atom_#{System.unique_integer([:positive])}")
      assert received_order_by() == nil

      visit(conn, "/interface?sort=rating")
      assert received_order_by() == nil

      visit(conn, "/interface?sort[]=rating&sort[]=-title")
      assert received_order_by() == [desc: :title]

      visit(conn, "/interface?sort[]=rating&sort[]=missing_field")
      assert received_order_by() == nil
    end

    test "shows the sort direction and links to the opposite direction", %{conn: conn} do
      books_interface()

      session = visit(conn, "/interface?page=3&sort=title")

      assert classes_of_sort(session) == [
               "pax-index-table-header-sort pax-index-table-header-sort-asc pax-index-table-header-sort-1"
             ]

      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Ascending"]
      assert count(html(session), ".pax-index-table-sort-num") == 0
      assert header_links(session) == ["/interface?sort=-title", "/interface?sort=~rank", "/interface?sort=page_count"]

      session = visit(conn, "/interface?sort=-title")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Descending"]
      assert header_links(session) |> hd() == "/interface?sort=title"

      session = visit(conn, "/interface?sort=~rank")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Ascending (nulls first)"]
      assert header_links(session) |> Enum.at(1) == "/interface?sort=-.rank"

      session = visit(conn, "/interface?sort=-.rank")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Descending (nulls last)"]
      assert header_links(session) |> Enum.at(1) == "/interface?sort=~rank"

      session = visit(conn, "/interface?sort=.rank")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Ascending (nulls last)"]

      session = visit(conn, "/interface?sort=-~rank")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Descending (nulls first)"]
    end

    defp classes_of_sort(session), do: PaxTest.HTML.classes(html(session), ".pax-index-table-header-sort")
    defp header_links(session), do: attr(html(session), "th a.pax-index-table-header-link", "href")
  end

  describe "sorting with the default criteria" do
    test "shows the default sort, and leaves it out of links", %{conn: conn} do
      books_interface(default_criteria: [order_by: :title])

      session = visit(conn, "/interface")
      assert received_order_by() == :title
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Ascending"]
      assert header_links(session) == ["/interface?sort=-title", "/interface?sort=~rank", "/interface?sort=page_count"]

      session = visit(conn, "/interface?sort=-title")
      assert header_links(session) |> hd() == "/interface"
    end

    test "supports lists of fields and directions", %{conn: conn} do
      books_interface(default_criteria: [order_by: [:title]])
      session = visit(conn, "/interface?sort=-title")
      assert header_links(session) |> hd() == "/interface"

      books_interface(default_criteria: [order_by: [desc_nulls_last: :rank]])
      session = visit(conn, "/interface")
      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["Descending (nulls last)"]
      assert header_links(session) |> Enum.at(1) == "/interface?sort=~rank"

      books_interface(default_criteria: [order_by: [:title, desc: :rank]])
      session = visit(conn, "/interface")
      assert texts(html(session), ".pax-index-table-sort-num") == ["1", "2"]
      assert header_links(session) |> hd() == "/interface?sort=-title"
    end

    test "uses the default direction of each field in links", %{conn: conn} do
      fields = [
        {:title, :string, sort: true, sort_asc: :asc_nulls_last, sort_desc: :desc_nulls_first},
        {:rank, :integer, sort: true}
      ]

      books_interface(fields: fields, default_criteria: [order_by: [asc_nulls_last: :title, desc_nulls_first: :rank]])
      session = visit(conn, "/interface")

      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == [
               "Ascending (nulls last)",
               "Descending (nulls first)"
             ]

      assert header_links(session) == ["/interface?sort=-~title", "/interface?sort=rank"]
    end

    test "shows sorts on fields that aren't sortable, and unknown directions", %{conn: conn} do
      books_interface(default_criteria: [order_by: [:rating, sideways: :title, other: "bad"]])
      session = visit(conn, "/interface")
      assert count(html(session), ".pax-index-table-header-sort") == 0

      books_interface(default_criteria: [order_by: [:rating, sideways: :title]])
      session = visit(conn, "/interface")

      assert attr(html(session), ".pax-index-table-sort-icon[title]", "title") == ["sideways", "Ascending"]

      assert PaxTest.HTML.classes(html(session), ".pax-index-table-header-sort") |> Enum.at(1) =~
               "pax-index-table-header-sort-asc"
    end
  end

  describe "after_params/2" do
    defp after_params(criteria) do
      pax = %Pax.Interface{criteria: criteria}
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, pax: pax}}
      {:cont, socket} = IndexTable.after_params(%{}, socket)
      socket.assigns.pax.private.index_table.sorts
    end

    test "tracks the order and direction of each sorted field" do
      assert after_params(%{}) == %{}
      assert after_params(%{order_by: :title}) == %{title: {1, :asc}}
      assert after_params(%{order_by: [:title, desc: :rank, asc: :title]}) == %{title: {1, :asc}, rank: {2, :desc}}
    end

    test "ignores unsupported order_by criteria" do
      assert after_params(%{order_by: "title"}) == %{}
      assert after_params(%{order_by: [:title, {"desc", :rank}]}) == %{}
    end
  end
end
