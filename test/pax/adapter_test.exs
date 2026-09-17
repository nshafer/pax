defmodule Pax.AdapterTest do
  use ExUnit.Case, async: true

  alias Pax.Adapter

  defmodule FakeAdapter do
    @behaviour Pax.Adapter

    def init(callback_module, opts), do: %{callback_module: callback_module, opts: opts}
    def config_spec(opts), do: %{spec_for: [:atom], opts: opts}
    def merge_config(opts, config, _socket), do: Map.put(opts, :config, config)
    def default_fields(_opts), do: [:a, :b]
    def field_type(_opts, :good), do: {:ok, :string}
    def field_type(_opts, :bad), do: {:error, "bad field"}
    def singular_name(_opts), do: "Thing"
    def plural_name(_opts), do: "Things"
    def count_objects(_opts, criteria), do: {:count, criteria}
    def list_objects(_opts, criteria), do: {:list, criteria}
    def new_object(_opts, socket), do: {:new, socket}
    def get_object(_opts, lookup, criteria, socket), do: {:get, lookup, criteria, socket}
    def id_fields(%{opts: opts}), do: Keyword.get(opts, :id_fields)
    def object_ids(%{opts: opts}, object), do: Keyword.get(opts, :object_ids, fn _ -> nil end).(object)
    def object_name(_opts, object), do: "Thing #{object.id}"
    def change_object(_opts, object, params, fields), do: {:change, object, params, fields}
    def create_object(_opts, object, changeset), do: {:create, object, changeset}
    def update_object(_opts, object, changeset), do: {:update, object, changeset}
  end

  defp adapter(opts \\ []), do: Adapter.init(FakeAdapter, :callback, opts)

  test "init/3 builds the adapter struct with the adapter's initialized opts" do
    assert %Adapter{module: FakeAdapter, opts: %{callback_module: :callback, opts: [id_fields: [:id]]}} =
             Adapter.init(FakeAdapter, :callback, id_fields: [:id])

    assert %Adapter{opts: %{opts: []}} = Adapter.init(FakeAdapter, :callback)
  end

  test "adapter?/1" do
    assert Adapter.adapter?(adapter())
    refute Adapter.adapter?(nil)
    refute Adapter.adapter?(FakeAdapter)
  end

  test "config_spec/1 and merge_config/3 delegate to the adapter" do
    assert %{spec_for: [:atom]} = Adapter.config_spec(adapter())
    assert %Adapter{opts: %{config: %{key: :value}}} = Adapter.merge_config(adapter(), %{key: :value}, :socket)
  end

  test "field_type!/2 returns the type or raises the adapter's error" do
    assert Adapter.field_type!(adapter(), :good) == :string
    assert_raise RuntimeError, "bad field", fn -> Adapter.field_type!(adapter(), :bad) end
  end

  test "the data functions delegate to the adapter" do
    assert Adapter.default_fields(adapter()) == [:a, :b]
    assert Adapter.singular_name(adapter()) == "Thing"
    assert Adapter.plural_name(adapter()) == "Things"
    assert Adapter.count_objects(adapter(), %{limit: 1}) == {:count, %{limit: 1}}
    assert Adapter.list_objects(adapter(), %{limit: 1}) == {:list, %{limit: 1}}
    assert Adapter.new_object(adapter(), :socket) == {:new, :socket}
    assert Adapter.get_object(adapter(), %{id: 1}, %{}, :socket) == {:get, %{id: 1}, %{}, :socket}
    assert Adapter.object_name(adapter(), %{id: 1}) == "Thing 1"
    assert Adapter.change_object(adapter(), :obj, %{}, []) == {:change, :obj, %{}, []}
    assert Adapter.create_object(adapter(), :obj, :cs) == {:create, :obj, :cs}
    assert Adapter.update_object(adapter(), :obj, :cs) == {:update, :obj, :cs}
  end

  test "id_fields/1 returns the adapter's id fields" do
    assert Adapter.id_fields(adapter(id_fields: [:a, :b])) == [:a, :b]
    assert Adapter.id_fields(adapter()) == nil
  end

  describe "object_ids/2" do
    test "uses the adapter's ids" do
      assert Adapter.object_ids(adapter(object_ids: fn obj -> [obj.slug] end), %{slug: "s"}) == ["s"]
    end

    test "falls back to the values of the id fields" do
      assert Adapter.object_ids(adapter(id_fields: [:org, :id]), %{org: 1, id: 2}) == [1, 2]
      assert Adapter.object_ids(adapter(), %{id: 1}) == []
    end

    test "raises when the adapter returns something other than a list or nil" do
      assert_raise ArgumentError, "object_ids must return a list or nil", fn ->
        Adapter.object_ids(adapter(object_ids: fn _ -> "1" end), %{id: 1})
      end
    end
  end
end

defmodule Pax.Adapters.EctoSchemaTest do
  use ExUnit.Case, async: true

  alias Pax.Adapters.EctoSchema
  alias PaxTest.Book
  alias PaxTest.Repo

  @opts %{repo: Repo, schema: Book}

  defp query_string(query), do: query |> Inspect.Ecto.Query.to_string() |> PaxTest.HTML.squish()

  defp received_query(function) do
    assert_received {Repo, ^function, [query | _]}
    query_string(query)
  end

  describe "init/2" do
    test "takes the repo and schema from the opts" do
      assert EctoSchema.init(nil, repo: Repo, schema: Book) == %{repo: Repo, schema: Book}
      assert EctoSchema.init(nil, []) == %{repo: nil, schema: nil}
    end
  end

  describe "config_spec/1" do
    test "is a valid spec" do
      assert {:ok, _} = Pax.Config.validate(EctoSchema.config_spec(%{}), %{}, validate_config_spec: true)
    end
  end

  describe "merge_config/3" do
    test "keeps the init opts when not configured" do
      assert EctoSchema.merge_config(@opts, %{}, :socket) == @opts
    end

    test "overrides the init opts with the config" do
      config = Pax.Config.validate!(EctoSchema.config_spec(%{}), repo: Repo, schema: fn :socket -> Book end)
      assert EctoSchema.merge_config(%{repo: nil, schema: nil}, config, :socket) == @opts
    end

    test "raises when the repo or schema is missing" do
      assert_raise RuntimeError, ~r/Missing required configuration for EctoSchema adapter/, fn ->
        EctoSchema.merge_config(%{repo: Repo, schema: nil}, %{}, :socket)
      end

      assert_raise RuntimeError, ~r/You must provide a `repo` and `schema`/, fn ->
        EctoSchema.merge_config(%{repo: nil, schema: Book}, %{}, :socket)
      end
    end
  end

  describe "field_type/2" do
    test "maps schema types to field types" do
      opts = %{schema: PaxTest.AllTypes}

      assert EctoSchema.field_type(opts, :uuid) == {:ok, :string}
      assert EctoSchema.field_type(opts, :ref_id) == {:ok, :integer}
      assert EctoSchema.field_type(opts, :integer) == {:ok, :integer}
      assert EctoSchema.field_type(opts, :float) == {:ok, :float}
      assert EctoSchema.field_type(opts, :boolean) == {:ok, :boolean}
      assert EctoSchema.field_type(opts, :string) == {:ok, :string}
      assert EctoSchema.field_type(opts, :date) == {:ok, :date}
      assert EctoSchema.field_type(opts, :time) == {:ok, :time}
      assert EctoSchema.field_type(opts, :time_usec) == {:ok, :time}
      assert EctoSchema.field_type(opts, :naive_datetime) == {:ok, :datetime}
      assert EctoSchema.field_type(opts, :naive_datetime_usec) == {:ok, :datetime}
      assert EctoSchema.field_type(opts, :utc_datetime) == {:ok, :datetime}
      assert EctoSchema.field_type(opts, :utc_datetime_usec) == {:ok, :datetime}
      assert EctoSchema.field_type(opts, :ecto_uuid) == {:ok, :string}
    end

    test "returns errors for unsupported types" do
      opts = %{schema: PaxTest.AllTypes}

      assert EctoSchema.field_type(opts, :binary) == {:error, ":binary fields are not supported"}
      assert EctoSchema.field_type(opts, :array) == {:error, "TODO: arrays"}
      assert EctoSchema.field_type(opts, :map) == {:error, "TODO: maps"}
      assert EctoSchema.field_type(opts, :typed_map) == {:error, "TODO: maps"}
      assert EctoSchema.field_type(opts, :decimal) == {:error, "TODO: decimals"}

      # Ecto.Enum is a parameterized type, so it is reported as unknown rather than matching the `Ecto.Enum` clause
      assert {:error, message} = EctoSchema.field_type(opts, :enum)
      assert message =~ "Unknown schema type {:parameterized, {Ecto.Enum"

      assert {:error, message} = EctoSchema.field_type(opts, :custom)
      assert message =~ "Unknown schema type PaxTest.CustomType in schema PaxTest.AllTypes"
    end

    test "returns an error for unknown fields" do
      assert EctoSchema.field_type(@opts, :nope) == {:error, "Unknown field :nope for schema PaxTest.Book"}
    end
  end

  describe "default_fields/1" do
    test "lists every schema field with its type" do
      assert EctoSchema.default_fields(@opts) == [
               id: :integer,
               title: :string,
               rank: :integer,
               rating: :float,
               in_print: :boolean,
               published: :date,
               read_at: :time,
               uuid: :string,
               inserted_at: :datetime,
               updated_at: :datetime
             ]
    end

    test "skips fields with unsupported types" do
      assert EctoSchema.default_fields(%{schema: PaxTest.AllTypes}) == [
               uuid: :string,
               ref_id: :integer,
               integer: :integer,
               float: :float,
               boolean: :boolean,
               string: :string,
               date: :date,
               time: :time,
               time_usec: :time,
               naive_datetime: :datetime,
               naive_datetime_usec: :datetime,
               utc_datetime: :datetime,
               utc_datetime_usec: :datetime,
               ecto_uuid: :string
             ]
    end
  end

  describe "names" do
    test "are introspected from the schema" do
      assert EctoSchema.singular_name(@opts) == "Book"
      assert EctoSchema.plural_name(@opts) == "Books"
    end

    test "object_name/2 includes the primary keys" do
      assert EctoSchema.object_name(@opts, %Book{id: 7}) == "Book 7"

      opts = %{schema: PaxTest.Membership}
      assert EctoSchema.object_name(opts, %PaxTest.Membership{org_id: 1, user_id: 2}) == "Membership org_id:1 user_id:2"

      assert EctoSchema.object_name(%{schema: PaxTest.NoKey}, %PaxTest.NoKey{}) == "Nokey"
    end
  end

  describe "id_fields/1 and object_ids/2" do
    test "use the schema's primary key" do
      assert EctoSchema.id_fields(@opts) == [:id]
      assert EctoSchema.id_fields(%{schema: PaxTest.Membership}) == [:org_id, :user_id]
      assert EctoSchema.object_ids(@opts, %Book{id: 1}) == nil
    end
  end

  describe "count_objects/2" do
    test "counts with the repo" do
      Repo.stub(:aggregate, fn _query, :count -> 42 end)

      assert EctoSchema.count_objects(@opts, %{limit: 10, offset: 10}) == 42
      assert_received {Repo, :aggregate, [query, :count]}
      assert query_string(query) == "from b0 in PaxTest.Book"
    end

    test "applies the where criteria, like list_objects/2" do
      EctoSchema.count_objects(@opts, %{where: [title: "Dune"]})
      assert received_query(:aggregate) == ~s(from b0 in PaxTest.Book, where: b0.title == ^"Dune")
    end
  end

  describe "list_objects/2" do
    test "lists with the repo" do
      Repo.stub(:all, fn _query -> [%Book{id: 1}] end)

      assert EctoSchema.list_objects(@opts, %{}) == [%Book{id: 1}]
      assert received_query(:all) == "from b0 in PaxTest.Book"
    end

    test "applies the where, order_by, limit and offset criteria" do
      criteria = %{where: [title: "Dune"], order_by: [asc: :title, desc: :rank], limit: 10, offset: 20}
      EctoSchema.list_objects(@opts, criteria)

      assert received_query(:all) ==
               ~s(from b0 in PaxTest.Book, where: b0.title == ^"Dune", order_by: [asc: b0.title, desc: b0.rank], limit: ^10, offset: ^20)
    end

    test "applies a limit without an offset" do
      EctoSchema.list_objects(@opts, %{order_by: :title, limit: 5})
      assert received_query(:all) == "from b0 in PaxTest.Book, order_by: [asc: b0.title], limit: ^5"
    end

    test "ignores an offset without a limit" do
      EctoSchema.list_objects(@opts, %{offset: 5})
      assert received_query(:all) == "from b0 in PaxTest.Book"
    end
  end

  describe "new_object/2" do
    test "returns an empty struct" do
      assert EctoSchema.new_object(@opts, :socket) == %Book{}
    end
  end

  describe "get_object/4" do
    test "gets one object by the lookup and where criteria" do
      Repo.stub(:one!, fn _query -> %Book{id: 1} end)

      assert EctoSchema.get_object(@opts, %{id: "1"}, %{where: [rank: 1], limit: 10}, :socket) == %Book{id: 1}
      assert received_query(:one!) == ~s(from b0 in PaxTest.Book, where: b0.rank == ^1, where: b0.id == ^"1")
    end

    test "supports composite lookups" do
      Repo.stub(:one!, fn _query -> %PaxTest.Membership{} end)
      EctoSchema.get_object(%{repo: Repo, schema: PaxTest.Membership}, %{org_id: "1", user_id: "2"}, %{}, :socket)

      query = received_query(:one!)
      assert query =~ ~s(m0.org_id == ^"1")
      assert query =~ ~s(m0.user_id == ^"2")
    end
  end

  describe "change_object/4" do
    test "casts only mutable fields and requires required ones" do
      fields = [
        Pax.Field.init(nil, {:title, :string}),
        Pax.Field.init(nil, {:rank, :integer, required: false}),
        Pax.Field.init(nil, {:rating, :float, immutable: true})
      ]

      params = %{"title" => "", "rank" => "3", "rating" => "5.0"}
      changeset = EctoSchema.change_object(@opts, %Book{}, params, fields)

      assert changeset.changes == %{rank: 3}
      assert changeset.errors == [title: {"can't be blank", [validation: :required]}]
    end
  end

  describe "create_object/3 and update_object/3" do
    test "insert and update with the repo" do
      changeset = Ecto.Changeset.change(%Book{}, title: "Dune")

      assert {:ok, %Book{title: "Dune"}} = EctoSchema.create_object(@opts, %Book{}, changeset)
      assert_received {Repo, :insert, [^changeset]}

      assert {:ok, %Book{title: "Dune"}} = EctoSchema.update_object(@opts, %Book{}, changeset)
      assert_received {Repo, :update, [^changeset]}
    end
  end
end
