defmodule Pax.Interface.InitTest do
  use ExUnit.Case, async: true

  alias Pax.Interface.Init
  alias PaxTest.FakeAdapter
  alias PaxTest.InterfaceLive
  alias PaxTest.Owner

  defmodule NilSpecPlugin do
    use Pax.Interface.Plugin
    def config_key, do: :nil_spec
    def config_spec, do: nil
  end

  defmodule BadSpecPlugin do
    use Pax.Interface.Plugin
    def config_key, do: :bad_spec
    def config_spec, do: [:not_a_map]
  end

  defmodule DuplicateSpyPlugin do
    use Pax.Interface.Plugin
    def config_key, do: :spy
  end

  # Build a socket the way `Pax.Interface.Live` would have by the time `handle_params` runs.
  defp socket(opts \\ []) do
    adapter = Keyword.get(opts, :adapter)
    plugins = Keyword.get(opts, :plugins, [])
    action = Keyword.get(opts, :action, :index)
    config = Pax.Config.validate!(Init.init_config_spec(adapter, plugins), Keyword.get(opts, :config, []))

    pax = %Pax.Interface{
      module: InterfaceLive,
      config: config,
      adapter: adapter,
      plugins: plugins,
      action: action,
      path: Keyword.get(opts, :path, %URI{path: "/interface"}),
      object: Keyword.get(opts, :object),
      index_query: Keyword.get(opts, :index_query),
      criteria: Keyword.get(opts, :criteria, %{})
    }

    %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, flash: %{}, live_action: action, pax: pax}}
  end

  defp fake_adapter(opts \\ []), do: Pax.Adapter.init(FakeAdapter, InterfaceLive, opts)

  describe "init_adapter/2" do
    test "returns nil without an adapter" do
      assert Init.init_adapter(InterfaceLive, socket()) == nil
    end

    test "initializes an adapter module with the module as the callback module" do
      Owner.put(:pax_adapter, FakeAdapter)

      assert %Pax.Adapter{module: FakeAdapter, opts: %{callback_module: InterfaceLive}} =
               Init.init_adapter(InterfaceLive, socket())
    end

    test "initializes an adapter with opts" do
      Owner.put(:pax_adapter, {FakeAdapter, singular_name: "Thing"})

      assert %Pax.Adapter{opts: %{callback_module: InterfaceLive, singular_name: "Thing"}} =
               Init.init_adapter(InterfaceLive, socket())
    end

    test "initializes an adapter with a different callback module and opts" do
      Owner.put(:pax_adapter, {FakeAdapter, SomeModule, singular_name: "Thing"})

      assert %Pax.Adapter{opts: %{callback_module: SomeModule, singular_name: "Thing"}} =
               Init.init_adapter(InterfaceLive, socket())
    end

    test "raises on an invalid adapter" do
      Owner.put(:pax_adapter, "adapter")

      assert_raise ArgumentError, "Invalid adapter returned from PaxTest.InterfaceLive.pax_adapter/1", fn ->
        Init.init_adapter(InterfaceLive, socket())
      end
    end
  end

  describe "merge_adapter_config/3" do
    test "returns nil without an adapter" do
      assert Init.merge_adapter_config(nil, %{}, socket()) == nil
    end

    test "merges the adapter's section of the config" do
      adapter = fake_adapter()
      config = Pax.Config.validate!(Init.init_config_spec(adapter, []), adapter: [fake_key: "value"])

      assert %Pax.Adapter{opts: %{fake_key: "value"}} = Init.merge_adapter_config(adapter, config, socket())
      assert %Pax.Adapter{opts: %{fake_key: nil}} = Init.merge_adapter_config(adapter, %{}, socket())
    end
  end

  describe "init_plugins/2 and merge_plugins_config/3" do
    test "initializes each plugin with the module" do
      Owner.put(:pax_plugins, [PaxTest.BarePlugin, {PaxTest.SpyPlugin, halt: [:handle_info]}])

      assert [
               %Pax.Plugin{module: PaxTest.BarePlugin},
               %Pax.Plugin{module: PaxTest.SpyPlugin, opts: %{halt: [:handle_info]}}
             ] =
               Init.init_plugins(InterfaceLive, socket())

      assert_received {:spy, :init, InterfaceLive, [halt: [:handle_info]]}
    end

    test "raises when the plugins aren't a list" do
      Owner.put(:pax_plugins, fn _socket -> PaxTest.BarePlugin end)

      assert_raise ArgumentError, "Invalid plugins returned from PaxTest.InterfaceLive.plugins/1", fn ->
        Init.init_plugins(InterfaceLive, socket())
      end
    end

    test "merges each plugin's section of the config" do
      plugins = [Pax.Plugin.init(InterfaceLive, PaxTest.SpyPlugin), Pax.Plugin.init(InterfaceLive, PaxTest.BarePlugin)]
      config = Pax.Config.validate!(Init.init_config_spec(nil, plugins), plugins: [spy: [label: "configured"]])

      assert [%Pax.Plugin{opts: %{label: "configured"}}, %Pax.Plugin{opts: %{}}] =
               Init.merge_plugins_config(plugins, config, socket())

      assert [%Pax.Plugin{opts: %{label: "spy"}}, _] = Init.merge_plugins_config(plugins, %{}, socket())
    end
  end

  describe "init_config_spec/2" do
    test "namespaces the adapter and plugin specs" do
      plugins = [Pax.Plugin.init(InterfaceLive, PaxTest.SpyPlugin), Pax.Plugin.init(InterfaceLive, PaxTest.BarePlugin)]
      spec = Init.init_config_spec(fake_adapter(), plugins)

      assert Map.take(spec, [:singular_name, :fields]) ==
               Map.take(Pax.Interface.Config.config_spec(), [:singular_name, :fields])

      assert spec.adapter == FakeAdapter.config_spec(%{})
      assert spec.plugins == %{spy: PaxTest.SpyPlugin.config_spec()}

      assert %{adapter: %{}, plugins: %{}} = Init.init_config_spec(nil, [])
    end

    test "is a valid config spec" do
      plugins =
        for plugin <- [
              Pax.Plugins.ActionButtons,
              Pax.Plugins.Breadcrumbs,
              Pax.Plugins.DetailFieldsets,
              Pax.Plugins.DetailList,
              Pax.Plugins.IndexTable,
              Pax.Plugins.Pagination,
              Pax.Plugins.Title
            ],
            do: Pax.Plugin.init(InterfaceLive, plugin)

      adapter = Pax.Adapter.init(Pax.Adapters.EctoSchema, InterfaceLive, [])
      spec = Init.init_config_spec(adapter, plugins)

      assert {:ok, _} = Pax.Config.validate(spec, %{}, validate_config_spec: true)
    end

    test "skips plugins whose config spec is nil" do
      plugins = [Pax.Plugin.init(InterfaceLive, NilSpecPlugin)]
      assert Init.init_config_spec(nil, plugins).plugins == %{}
    end

    test "raises on an invalid plugin config spec" do
      plugins = [Pax.Plugin.init(InterfaceLive, BadSpecPlugin)]

      assert_raise ArgumentError, ~r/invalid config spec returned from .*BadSpecPlugin.config_spec\/0/, fn ->
        Init.init_config_spec(nil, plugins)
      end
    end

    test "raises when two plugins use the same config key" do
      plugins = [Pax.Plugin.init(InterfaceLive, PaxTest.SpyPlugin), Pax.Plugin.init(InterfaceLive, DuplicateSpyPlugin)]

      assert_raise ArgumentError, ~r/plugin .*DuplicateSpyPlugin defined duplicate config key :spy/, fn ->
        Init.init_config_spec(nil, plugins)
      end
    end
  end

  describe "init_config/3" do
    test "validates the module's config, as a keyword list or map" do
      spec = Init.init_config_spec(nil, [])

      Owner.put(:pax_config, singular_name: "Book")
      assert %{singular_name: {:string, "Book"}} = Init.init_config(spec, InterfaceLive, socket())

      Owner.put(:pax_config, %{plural_name: "Books"})
      assert %{plural_name: {:string, "Books"}} = Init.init_config(spec, InterfaceLive, socket())
    end

    test "raises when the config is invalid" do
      spec = Init.init_config_spec(nil, [])

      Owner.put(:pax_config, fn _socket -> "config" end)

      assert_raise ArgumentError, "invalid config returned from PaxTest.InterfaceLive.pax_config/1", fn ->
        Init.init_config(spec, InterfaceLive, socket())
      end

      Owner.put(:pax_config, singular_name: :book)
      assert_raise Pax.Config.TypeError, fn -> Init.init_config(spec, InterfaceLive, socket()) end

      Owner.put(:pax_config, made_up: true)

      assert_raise Pax.ConfigError, "invalid key :made_up in config", fn ->
        Init.init_config(spec, InterfaceLive, socket())
      end
    end
  end

  describe "action and path" do
    test "the action is the live_action" do
      assert Init.init_action(socket(action: :edit)) == :edit
      assert Init.assign_action(socket(action: :new)).assigns.pax.action == :new
    end

    test "the path only keeps the path and query of the uri" do
      assert Init.init_path("http://localhost:4000/books?page=2#top") == %URI{path: "/books", query: "page=2"}
      assert Init.assign_path(socket(), "http://localhost/books").assigns.pax.path == %URI{path: "/books"}
    end
  end

  describe "init_id_fields/1" do
    test "uses the config" do
      assert Init.init_id_fields(socket(config: [id_fields: [:slug]])) == [:slug]
      assert Init.init_id_fields(socket(config: [id_fields: fn _socket -> [:org, :slug] end])) == [:org, :slug]
    end

    test "falls back to the adapter, then [:id]" do
      assert Init.init_id_fields(socket(adapter: fake_adapter(id_fields: [:uuid]))) == [:uuid]
      assert Init.init_id_fields(socket(adapter: fake_adapter())) == [:id]
      assert Init.init_id_fields(socket()) == [:id]
    end
  end

  describe "init_fields/1" do
    test "initializes the configured fields" do
      socket = socket(config: [fields: [{:title, :string}, {:rank, :integer, label: "Place"}]])

      assert [%Pax.Field{name: :title, type: Pax.Field.String}, %Pax.Field{name: :rank, opts: %{label: "Place"}}] =
               Init.init_fields(socket)

      socket = socket(config: [fields: fn _socket -> [{:title, :string}] end])
      assert [%Pax.Field{name: :title}] = Init.init_fields(socket)
    end

    test "falls back to the adapter's default fields" do
      adapter = fake_adapter(default_fields: [{:title, :string}], field_types: %{rank: :integer})

      assert [%Pax.Field{name: :title}] = Init.init_fields(socket(adapter: adapter))

      assert [%Pax.Field{name: :rank, type: Pax.Field.Integer}] =
               Init.init_fields(socket(adapter: adapter, config: [fields: [:rank]]))

      assert Init.init_fields(socket()) == []
    end

    test "filters fields by the only and except opts" do
      fields = [
        {:a, :string, only: :index},
        {:b, :string, only: [:show, :edit]},
        {:c, :string, except: :index},
        {:d, :string, except: [:new, :edit]},
        {:e, :string}
      ]

      names = fn action ->
        socket(action: action, config: [fields: fields]) |> Init.init_fields() |> Enum.map(& &1.name)
      end

      assert names.(:index) == [:a, :d, :e]
      assert names.(:show) == [:b, :c, :d, :e]
      assert names.(:edit) == [:b, :c, :e]
      assert names.(:new) == [:c, :e]
    end

    test "resolves link: true to the show path, or else the edit path" do
      book = %{id: 1}

      socket =
        socket(
          config: [
            fields: [{:title, :string}, {:rank, :integer, link: true}],
            show_path: fn object, _socket -> "/books/#{object.id}" end,
            edit_path: fn object, _socket -> "/books/#{object.id}/edit" end
          ]
        )

      assert [title, rank] = Init.init_fields(socket)
      refute Map.has_key?(title.opts, :link)
      assert Pax.Field.link(rank, book) == "/books/1"

      socket =
        socket(config: [fields: [{:rank, :integer, link: true}], edit_path: fn o, _ -> "/books/#{o.id}/edit" end])

      assert [rank] = Init.init_fields(socket)
      assert Pax.Field.link(rank, book) == "/books/1/edit"
    end

    test "raises on link: true without a show or edit path" do
      assert_raise RuntimeError, "You must configure either :show_path or :edit_path to use link: true", fn ->
        Init.init_fields(socket(config: [fields: [{:title, :string, link: true}]]))
      end
    end

    test "links the first field when no field has a link" do
      book = %{id: 1}

      socket =
        socket(config: [fields: [{:title, :string}, {:rank, :integer}], show_path: fn o, _ -> "/books/#{o.id}" end])

      assert [title, rank] = Init.init_fields(socket)
      assert Pax.Field.link(title, book) == "/books/1"
      assert Pax.Field.link(rank, book) == nil

      socket = socket(config: [fields: [{:title, :string}], edit_path: fn o, _ -> "/books/#{o.id}/edit" end])
      assert [title] = Init.init_fields(socket)
      assert Pax.Field.link(title, book) == "/books/1/edit"

      socket = socket(config: [fields: [{:title, :string}]])
      assert [title] = Init.init_fields(socket)
      assert Pax.Field.link(title, book) == nil
    end

    test "doesn't link the first field when another field has a link" do
      socket =
        socket(
          config: [fields: [{:title, :string}, {:rank, :integer, link: "/rank"}], show_path: fn _, _ -> "/show" end]
        )

      assert [title, rank] = Init.init_fields(socket)
      assert Pax.Field.link(title, %{}) == nil
      assert Pax.Field.link(rank, %{}) == "/rank"
    end

    test "only links fields that are in the action" do
      socket =
        socket(
          action: :index,
          config: [fields: [{:title, :string, only: :show}, {:rank, :integer}], show_path: fn _, _ -> "/show" end]
        )

      assert [rank] = Init.init_fields(socket)
      assert Pax.Field.link(rank, %{}) == "/show"
    end
  end

  describe "names" do
    test "use the config" do
      socket = socket(config: [singular_name: "Book", plural_name: fn _socket -> "Books" end])

      assert Init.init_singular_name(socket) == "Book"
      assert Init.init_plural_name(socket) == "Books"
    end

    test "fall back to the adapter" do
      socket = socket(adapter: fake_adapter(singular_name: "Thing", plural_name: "Things"))

      assert Init.init_singular_name(socket) == "Thing"
      assert Init.init_plural_name(socket) == "Things"
    end

    test "fall back to Object and Objects" do
      assert Init.init_singular_name(socket()) == "Object"
      assert Init.init_plural_name(socket()) == "Objects"
      assert Init.init_singular_name(socket(adapter: fake_adapter())) == "Object"
      assert Init.init_plural_name(socket(adapter: fake_adapter())) == "Objects"
    end

    test "are assigned" do
      socket = socket() |> Init.assign_singular_name() |> Init.assign_plural_name()

      assert socket.assigns.pax.singular_name == "Object"
      assert socket.assigns.pax.plural_name == "Objects"
    end
  end

  describe "init_index_path/2" do
    test "is nil when not configured" do
      assert Init.init_index_path(%{}, socket()) == nil
    end

    test "is the current path, with query, on the index page" do
      socket = socket(action: :index, path: %URI{path: "/books", query: "page=2"}, config: [index_path: "/books"])
      assert Init.init_index_path(%{}, socket) == %URI{path: "/books", query: "page=2"}
    end

    test "is the configured path with the decoded index_query on other pages" do
      socket = socket(action: :show, config: [index_path: fn _socket -> "/books" end])

      assert Init.init_index_path(%{}, socket) == "/books"
      assert Init.init_index_path(%{"index_query" => "page%3D2%26sort%3Dtitle"}, socket) == "/books?page=2&sort=title"

      socket = socket(action: :show, config: [index_path: URI.parse("/books")])
      assert Init.init_index_path(%{"index_query" => "page%3D2"}, socket) == %URI{path: "/books", query: "page=2"}
    end

    test "is assigned" do
      socket = socket(action: :show, config: [index_path: "/books"])
      assert Init.assign_index_path(socket, %{}).assigns.pax.index_path == "/books"
    end
  end

  describe "init_new_path/2" do
    test "is nil when not configured" do
      assert Init.init_new_path(%{}, socket()) == nil
    end

    test "carries the current query as the index_query on the index page" do
      socket = socket(action: :index, path: %URI{path: "/books", query: "page=2"}, config: [new_path: "/books/new"])
      assert Init.init_new_path(%{}, socket) == "/books/new?index_query=page%253D2"

      socket = socket(action: :index, path: %URI{path: "/books"}, config: [new_path: "/books/new"])
      assert Init.init_new_path(%{}, socket) == "/books/new"
    end

    test "passes the index_query along on other pages" do
      socket = socket(action: :new, config: [new_path: fn _socket -> "/books/new" end])

      assert Init.init_new_path(%{"index_query" => "page%3D2"}, socket) == "/books/new?index_query=page%253D2"
      assert Init.init_new_path(%{}, socket) == "/books/new"
    end

    test "is assigned" do
      socket = socket(action: :new, config: [new_path: "/books/new"])
      assert Init.assign_new_path(socket, %{}).assigns.pax.new_path == "/books/new"
    end
  end

  describe "default criteria" do
    test "are empty by default" do
      assert Init.init_default_criteria(socket()) == %{}
    end

    test "can be a map, keyword list or function" do
      assert Init.init_default_criteria(socket(config: [default_criteria: %{limit: 1}])) == %{limit: 1}
      assert Init.init_default_criteria(socket(config: [default_criteria: [order_by: :title]])) == %{order_by: :title}
      assert Init.init_default_criteria(socket(config: [default_criteria: fn _ -> [limit: 2] end])) == %{limit: 2}
    end

    test "are assigned as the default criteria and the current criteria" do
      socket =
        socket(criteria: %{stale: true}, config: [default_criteria: [limit: 1]]) |> Init.assign_default_criteria()

      assert socket.assigns.pax.default_criteria == %{limit: 1}
      assert socket.assigns.pax.criteria == %{limit: 1}
    end
  end

  describe "init_object/3 for new objects" do
    test "uses the module's new_object/1" do
      Owner.put(:new_object, fn _socket -> %{title: "new"} end)
      assert Init.init_object(%{}, "/", socket(action: :new)) == %{title: "new"}
    end

    test "falls back to the adapter" do
      assert Init.init_object(%{}, "/", socket(action: :new, adapter: fake_adapter(new_object: %{title: "fake"}))) == %{
               title: "fake"
             }

      assert_received {FakeAdapter, :new_object}
    end

    test "raises without an adapter" do
      assert_raise RuntimeError,
                   ~r/You must either define a `new_object\/1` callback, or configure a Pax.Adapter/,
                   fn ->
                     Init.init_object(%{}, "/", socket(action: :new))
                   end
    end

    test "raises when new_object/1 doesn't return a map" do
      Owner.put(:new_object, fn _socket -> [] end)

      assert_raise RuntimeError, "new_object/1 must return an object (map), got: []", fn ->
        Init.init_object(%{}, "/", socket(action: :new))
      end
    end
  end

  describe "init_object/3 for existing objects" do
    test "uses the module's get_object/3 with the lookup and criteria" do
      Owner.put(:get_object, fn lookup, criteria, _socket -> %{lookup: lookup, criteria: criteria} end)
      socket = socket(action: :show, criteria: %{where: [active: true]})

      assert Init.init_object(%{"id" => "1"}, "/", socket) == %{lookup: %{id: "1"}, criteria: %{where: [active: true]}}
      assert %{lookup: %{id: "2"}} = Init.init_object(%{"id" => "2"}, "/", socket(action: :edit))
    end

    test "falls back to the adapter" do
      socket = socket(action: :show, criteria: %{limit: 1}, adapter: fake_adapter(object: %{id: 1}))

      assert Init.init_object(%{"id" => "1"}, "/", socket) == %{id: 1}
      assert_received {FakeAdapter, :get_object, %{id: "1"}, %{limit: 1}}
    end

    test "raises without an adapter" do
      assert_raise RuntimeError,
                   ~r/You must either define a `get_object\/3` callback, or configure a Pax.Adapter/,
                   fn ->
                     Init.init_object(%{"id" => "1"}, "/", socket(action: :show))
                   end
    end

    test "raises when get_object/3 doesn't return a map" do
      Owner.put(:get_object, fn _, _, _ -> nil end)

      assert_raise RuntimeError, "get_object/3 must return an object (map), got: nil", fn ->
        Init.init_object(%{"id" => "1"}, "/", socket(action: :show))
      end
    end

    test "is nil for other actions" do
      assert Init.init_object(%{}, "/", socket(action: :index)) == nil
    end

    test "is assigned" do
      Owner.put(:new_object, fn _socket -> %{title: "new"} end)
      assert Init.assign_object(socket(action: :new), %{}, "/").assigns.pax.object == %{title: "new"}
    end
  end

  describe "init_lookup/3" do
    test "uses the lookup config" do
      socket = socket(config: [lookup: fn params, uri, _socket -> %{slug: params["slug"], uri: uri} end])
      assert Init.init_lookup(%{"slug" => "dune"}, "/books/dune", socket) == %{slug: "dune", uri: "/books/dune"}
    end

    test "defaults to the id param and id field" do
      assert Init.init_lookup(%{"id" => "1", "other" => "2"}, "/", socket()) == %{id: "1"}
    end

    test "zips the lookup_params with the id_fields" do
      socket = socket(config: [lookup_params: ["org", "slug"], id_fields: [:org_id, :slug]])
      assert Init.init_lookup(%{"org" => "1", "slug" => "dune"}, "/", socket) == %{org_id: "1", slug: "dune"}

      socket = socket(config: [lookup_params: fn _ -> [:slug] end, id_fields: fn _ -> [:slug] end])
      assert Init.init_lookup(%{"slug" => "dune"}, "/", socket) == %{slug: "dune"}
    end

    test "zips the lookup_glob with the id_fields" do
      socket = socket(config: [lookup_glob: "ids", id_fields: [:org_id, :id]])
      assert Init.init_lookup(%{"ids" => ["1", "2"]}, "/", socket) == %{org_id: "1", id: "2"}

      socket = socket(config: [lookup_glob: fn _ -> "ids" end], adapter: fake_adapter(id_fields: [:uuid]))
      assert Init.init_lookup(%{"ids" => ["abc"]}, "/", socket) == %{uuid: "abc"}
    end

    test "uses the adapter's id fields, then [:id]" do
      assert Init.init_lookup(%{"id" => "1"}, "/", socket(adapter: fake_adapter())) == %{id: "1"}
      assert Init.init_lookup(%{"id" => "1"}, "/", socket(adapter: fake_adapter(id_fields: [:id]))) == %{id: "1"}
    end

    test "raises when both lookup_params and lookup_glob are configured" do
      socket = socket(config: [lookup_params: ["id"], lookup_glob: "ids"])

      assert_raise ArgumentError, "You can't define both :lookup_params and :lookup_glob in the config", fn ->
        Init.init_lookup(%{"id" => "1"}, "/", socket)
      end
    end

    test "raises when a param is missing" do
      assert_raise ArgumentError, "Missing param: id", fn -> Init.init_lookup(%{}, "/", socket()) end

      assert_raise ArgumentError, "Missing param: ids", fn ->
        Init.init_lookup(%{}, "/", socket(config: [lookup_glob: "ids"]))
      end
    end

    test "raises when the number of params and id fields don't match" do
      socket = socket(config: [lookup_glob: "ids"])

      assert_raise ArgumentError, "The number of params must match the number of id_fields", fn ->
        Init.init_lookup(%{"ids" => ["1", "2"]}, "/", socket)
      end
    end

    test "raises when the id fields aren't atoms" do
      socket = socket(config: [id_fields: ["id"]])

      assert_raise ArgumentError, ~s(id_fields must be a list of atoms, got "id"), fn ->
        Init.init_lookup(%{"id" => "1"}, "/", socket)
      end
    end
  end

  describe "init_object_name/1" do
    test "is Object without an object" do
      assert Init.init_object_name(socket(config: [object_name: "Named"])) == "Object"
    end

    test "uses the config" do
      assert Init.init_object_name(socket(object: %{id: 1}, config: [object_name: "Named"])) == "Named"

      assert Init.init_object_name(socket(object: %{id: 1}, config: [object_name: fn o, _ -> "Book #{o.id}" end])) ==
               "Book 1"
    end

    test "falls back to the adapter when not configured, or the config returns nil" do
      adapter = fake_adapter(object_name: fn object -> "Fake #{object.id}" end)

      assert Init.init_object_name(socket(object: %{id: 1}, adapter: adapter)) == "Fake 1"

      assert Init.init_object_name(
               socket(object: %{id: 1}, adapter: adapter, config: [object_name: fn _, _ -> nil end])
             ) == "Fake 1"
    end

    test "falls back to Object" do
      assert Init.init_object_name(socket(object: %{id: 1})) == "Object"
      assert Init.init_object_name(socket(object: %{id: 1}, adapter: fake_adapter())) == "Object"
    end

    test "is assigned" do
      assert Init.assign_object_name(socket()).assigns.pax.object_name == "Object"
    end
  end

  describe "show and edit paths" do
    setup do
      config = [
        show_path: fn object, _socket -> "/books/#{object.id}" end,
        edit_path: fn object, _socket -> "/books/#{object.id}/edit" end
      ]

      %{config: config}
    end

    test "are resolved with the object and index_query", %{config: config} do
      socket = socket(action: :show, object: %{id: 1}, config: config, index_query: "page%3D2")

      assert Init.init_show_path(socket) == "/books/1?index_query=page%253D2"
      assert Init.init_edit_path(socket) == "/books/1/edit?index_query=page%253D2"

      socket = socket(action: :show, object: %{id: 1}, config: config)
      assert Init.init_show_path(socket) == "/books/1"
      assert Init.init_edit_path(socket) == "/books/1/edit"
    end

    test "are nil when not configured" do
      socket = socket(action: :show, object: %{id: 1})

      assert Init.init_show_path(socket) == nil
      assert Init.init_edit_path(socket) == nil
    end

    test "are only assigned on the show and edit actions", %{config: config} do
      for action <- [:show, :edit] do
        socket =
          socket(action: action, object: %{id: 1}, config: config) |> Init.assign_show_path() |> Init.assign_edit_path()

        assert socket.assigns.pax.show_path == "/books/1"
        assert socket.assigns.pax.edit_path == "/books/1/edit"
      end

      for action <- [:index, :new] do
        socket =
          socket(action: action, object: %{id: 1}, config: config) |> Init.assign_show_path() |> Init.assign_edit_path()

        assert socket.assigns.pax.show_path == nil
        assert socket.assigns.pax.edit_path == nil
      end
    end
  end
end
