defmodule Pax.Interface.IndexTest do
  use PaxTest.ConnCase, async: true

  alias PaxTest.FakeAdapter

  @books [%{id: 1, title: "Dune", rank: 2}, %{id: 2, title: "Emma", rank: 1}]

  describe "with callbacks" do
    test "counts and lists objects with the criteria", %{conn: conn} do
      interface(
        pax_plugins: [Pax.Plugins.IndexTable],
        pax_config: [fields: [{:title, :string}, {:rank, :integer}], default_criteria: [order_by: :title]],
        count_objects: fn criteria, _socket ->
          Owner.notify({:count_objects, criteria})
          2
        end,
        list_objects: fn criteria, _socket ->
          Owner.notify({:list_objects, criteria})
          @books
        end
      )

      conn
      |> visit("/interface")
      |> assert_has("tr#pax-object-1 td", text: "Dune")
      |> assert_has("tr#pax-object-2 td", text: "Emma")

      assert_received {:count_objects, %{order_by: :title}}
      assert_received {:list_objects, %{order_by: :title}}
    end

    test "builds dom ids from every id field", %{conn: conn} do
      interface(
        pax_plugins: [Pax.Plugins.IndexTable],
        pax_config: [fields: [{:role, :string}], id_fields: [:org_id, :user_id]],
        count_objects: 1,
        list_objects: [%{org_id: 3, user_id: 4, role: "admin"}]
      )

      conn
      |> visit("/interface")
      |> assert_has("tr#pax-object-3-4", text: "admin")
    end

    test "raises when count_objects/2 doesn't return a non-negative integer", %{conn: conn} do
      interface(count_objects: fn _, _ -> -1 end, list_objects: [])

      assert_raise RuntimeError, "count_objects/2 must return a non-negative integer, got: -1", fn ->
        visit(conn, "/interface")
      end

      interface(count_objects: fn _, _ -> "2" end)

      assert_raise RuntimeError, ~s(count_objects/2 must return a non-negative integer, got: "2"), fn ->
        visit(conn, "/interface")
      end
    end

    test "raises when list_objects/2 doesn't return a list", %{conn: conn} do
      interface(count_objects: 0, list_objects: fn _, _ -> %{} end)

      assert_raise RuntimeError, "list_objects/2 must return a list of objects, got: %{}", fn ->
        visit(conn, "/interface")
      end
    end
  end

  describe "without callbacks" do
    test "falls back to the adapter", %{conn: conn} do
      interface(
        pax_adapter: {FakeAdapter, objects: @books, default_fields: [{:title, :string}]},
        pax_plugins: [Pax.Plugins.IndexTable],
        pax_config: [default_criteria: %{limit: 5}]
      )

      conn
      |> visit("/interface")
      |> assert_has("tr#pax-object-1", text: "Dune")
      |> assert_has("tr#pax-object-2", text: "Emma")

      assert_received {FakeAdapter, :count_objects, %{limit: 5}}
      assert_received {FakeAdapter, :list_objects, %{limit: 5}}
    end

    test "raises without an adapter", %{conn: conn} do
      assert_raise RuntimeError,
                   ~r/You must either define a `count_objects\/2` callback or configure a Pax.Adapter/,
                   fn ->
                     visit(conn, "/interface")
                   end

      interface(count_objects: 0)

      assert_raise RuntimeError,
                   ~r/You must either define a `list_objects\/2` callback, or configure a Pax.Adapter/,
                   fn ->
                     visit(conn, "/interface")
                   end
    end
  end
end
