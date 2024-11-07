defmodule Pax.ConfigTest do
  use ExUnit.Case, async: true
  alias Pax.Config

  defmodule TestStruct do
    defstruct [:field]
  end

  describe "validate/2 (config specs)" do
    test "accepts all possible config specs" do
      assert {:ok, %{}} = Config.validate(%{foo: nil}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :atom}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :string}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :boolean}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :integer}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :float}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :tuple}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :list}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :map}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :module}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :struct}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:struct, TestStruct}}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :date}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :time}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :naive_datetime}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :datetime}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :uri}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: :function}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:function, 2}}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:function, :atom}}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:function, [:atom, :string]}}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:function, 2, :boolean}}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: {:function, 2, [:boolean, :integer]}}, %{})
    end

    test "accepts specs with lists of types" do
      assert {:ok, %{}} = Config.validate(%{foo: [nil, :atom, :string, :boolean, :integer, :float]}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: [:tuple, :list, :map, :module, :struct, {:struct, TestStruct}]}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: [:date, :time, :naive_datetime, :datetime, :uri]}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: [:function, {:function, 2}]}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: [{:function, :atom}, {:function, [:atom, :string]}]}, %{})
      assert {:ok, %{}} = Config.validate(%{foo: [{:function, 2, :boolean}, {:function, 2, [:boolean, :integer]}]}, %{})
    end

    test "does not raise if validate_config_spec is not set to true" do
      assert {:ok, %{}} = Config.validate(%{"foo" => :atom}, %{})
    end

    test "raises error if invalid key type" do
      assert_raise Pax.Config.SpecError, ~r/invalid key/, fn ->
        Config.validate(%{"foo" => :atom}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid key/, fn ->
        Config.validate!(%{"foo" => :atom}, %{}, validate_config_spec: true)
      end
    end

    test "raises error if invalid type" do
      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: :invalid}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: :invalid}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: 1}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: 1}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: [:atom, 2]}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: [:atom, 2]}, %{}, validate_config_spec: true)
      end
    end

    test "raises error if invalid arity" do
      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate(%{foo: {:function, -1}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate!(%{foo: {:function, -1}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate(%{foo: {:function, -1, :atom}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate!(%{foo: {:function, -1, :atom}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate(%{foo: {:function, -1, [:atom, :string]}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid arity/, fn ->
        Config.validate!(%{foo: {:function, -1, [:atom, :string]}}, %{}, validate_config_spec: true)
      end
    end

    test "raises error if invalid return type" do
      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: {:function, :invalid}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: {:function, :invalid}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: {:function, 1, :invalid}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: {:function, 1, :invalid}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: {:function, 1, [:invalid, :integer]}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: {:function, 1, [:invalid, :integer]}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate(%{foo: {:function, 1, [:integer, :invalid]}}, %{}, validate_config_spec: true)
      end

      assert_raise Pax.Config.SpecError, ~r/invalid type/, fn ->
        Config.validate!(%{foo: {:function, 1, [:integer, :invalid]}}, %{}, validate_config_spec: true)
      end
    end
  end

  describe "validate/2 (config data)" do
    test "accepts basic types with data" do
      assert {:ok, config} = Config.validate(%{foo: nil}, %{foo: nil})
      assert config[:foo] == %{value: nil, type: nil}
      assert {:ok, config} = Config.validate(%{foo: :atom}, %{foo: :foo})
      assert config[:foo] == %{value: :foo, type: :atom}
      assert {:ok, config} = Config.validate(%{foo: :string}, %{foo: "bar"})
      assert config[:foo] == %{value: "bar", type: :string}
      assert {:ok, config} = Config.validate(%{foo: :boolean}, %{foo: true})
      assert config[:foo] == %{value: true, type: :boolean}
      assert {:ok, config} = Config.validate(%{foo: :integer}, %{foo: 42})
      assert config[:foo] == %{value: 42, type: :integer}
      assert {:ok, config} = Config.validate(%{foo: :float}, %{foo: 3.14})
      assert config[:foo] == %{value: 3.14, type: :float}
      assert {:ok, config} = Config.validate(%{foo: :tuple}, %{foo: {1, 2, 3}})
      assert config[:foo] == %{value: {1, 2, 3}, type: :tuple}
      assert {:ok, config} = Config.validate(%{foo: :list}, %{foo: [1, 2, 3]})
      assert config[:foo] == %{value: [1, 2, 3], type: :list}
      assert {:ok, config} = Config.validate(%{foo: :map}, %{foo: %{foo: "bar"}})
      assert config[:foo] == %{value: %{foo: "bar"}, type: :map}
      assert {:ok, config} = Config.validate(%{foo: :module}, %{foo: Pax.Config})
      assert config[:foo] == %{value: Pax.Config, type: :module}
      assert {:ok, config} = Config.validate(%{foo: :struct}, %{foo: %TestStruct{field: "value"}})
      assert config[:foo] == %{value: %TestStruct{field: "value"}, type: :struct}
      assert {:ok, config} = Config.validate(%{foo: {:struct, TestStruct}}, %{foo: %TestStruct{field: "value"}})
      assert config[:foo] == %{value: %TestStruct{field: "value"}, type: {:struct, TestStruct}}
      assert {:ok, config} = Config.validate(%{foo: :date}, %{foo: ~D[2024-08-31]})
      assert config[:foo] == %{value: ~D[2024-08-31], type: :date}
      assert {:ok, config} = Config.validate(%{foo: :time}, %{foo: ~T[12:34:56]})
      assert config[:foo] == %{value: ~T[12:34:56], type: :time}
      assert {:ok, config} = Config.validate(%{foo: :naive_datetime}, %{foo: ~N[2024-08-31 12:34:56]})
      assert config[:foo] == %{value: ~N[2024-08-31 12:34:56], type: :naive_datetime}
      assert {:ok, config} = Config.validate(%{foo: :datetime}, %{foo: ~U[2024-08-31 12:34:56Z]})
      assert config[:foo] == %{value: ~U[2024-08-31 12:34:56Z], type: :datetime}
      assert {:ok, config} = Config.validate(%{foo: :uri}, %{foo: URI.parse("http://example.com")})
      assert config[:foo] == %{value: URI.parse("http://example.com"), type: :uri}
      assert {:ok, config} = Config.validate(%{foo: :function}, data = %{foo: fn -> :ok end})
      assert config[:foo] == %{value: data[:foo], type: :function}
      assert {:ok, config} = Config.validate(%{foo: {:function, 2}}, data = %{foo: fn a, b -> a + b end})
      assert config[:foo] == %{value: data[:foo], type: {:function, 2}}
      assert {:ok, config} = Config.validate(%{foo: {:function, :atom}}, data = %{foo: fn -> :ok end})
      assert config[:foo] == %{value: data[:foo], type: {:function, :atom}}
      assert {:ok, config} = Config.validate(%{foo: {:function, [:atom, :string]}}, data = %{foo: fn -> :ok end})
      assert config[:foo] == %{value: data[:foo], type: {:function, [:atom, :string]}}
      assert {:ok, config} = Config.validate(%{foo: {:function, 2, :boolean}}, data = %{foo: fn a, b -> a == b end})
      assert config[:foo] == %{value: data[:foo], type: {:function, 2, :boolean}}
      assert {:ok, config} = Config.validate(%{foo: {:function, 2, [:atom, nil]}}, data = %{foo: fn a, b -> a || b end})
      assert config[:foo] == %{value: data[:foo], type: {:function, 2, [:atom, nil]}}
    end

    test "accepts lists of types with data" do
      assert {:ok, config} = Config.validate(%{foo: [nil, :atom]}, %{foo: nil})
      assert config[:foo] == %{value: nil, type: nil}
      assert {:ok, config} = Config.validate(%{foo: [nil, :atom]}, %{foo: :bar})
      assert config[:foo] == %{value: :bar, type: :atom}

      assert {:ok, config} = Config.validate(%{foo: [:string, :boolean]}, %{foo: "bar"})
      assert config[:foo] == %{value: "bar", type: :string}
      assert {:ok, config} = Config.validate(%{foo: [:string, :boolean]}, %{foo: true})
      assert config[:foo] == %{value: true, type: :boolean}

      assert {:ok, config} = Config.validate(%{foo: [:integer, :float]}, %{foo: 42})
      assert config[:foo] == %{value: 42, type: :integer}
      assert {:ok, config} = Config.validate(%{foo: [:integer, :float]}, %{foo: 3.14})
      assert config[:foo] == %{value: 3.14, type: :float}

      assert {:ok, config} = Config.validate(%{foo: [:tuple, :list]}, %{foo: {1, 2, 3}})
      assert config[:foo] == %{value: {1, 2, 3}, type: :tuple}
      assert {:ok, config} = Config.validate(%{foo: [:tuple, :list]}, %{foo: [1, 2, 3]})
      assert config[:foo] == %{value: [1, 2, 3], type: :list}

      assert {:ok, config} = Config.validate(%{foo: [:map, :module]}, %{foo: %{foo: "bar"}})
      assert config[:foo] == %{value: %{foo: "bar"}, type: :map}
      assert {:ok, config} = Config.validate(%{foo: [:map, :module]}, %{foo: Pax.Config})
      assert config[:foo] == %{value: Pax.Config, type: :module}

      assert {:ok, config} = Config.validate(%{foo: [:struct, nil]}, %{foo: %TestStruct{field: "value"}})
      assert config[:foo] == %{value: %TestStruct{field: "value"}, type: :struct}
      assert {:ok, config} = Config.validate(%{foo: [:struct, nil]}, %{foo: nil})
      assert config[:foo] == %{value: nil, type: nil}

      assert {:ok, config} = Config.validate(%{foo: [{:struct, TestStruct}, nil]}, %{foo: %TestStruct{field: "value"}})
      assert config[:foo] == %{value: %TestStruct{field: "value"}, type: {:struct, TestStruct}}
      assert {:ok, config} = Config.validate(%{foo: [{:struct, TestStruct}, nil]}, %{foo: nil})
      assert config[:foo] == %{value: nil, type: nil}

      assert {:ok, config} = Config.validate(%{foo: [:date, :time]}, %{foo: ~D[2024-08-31]})
      assert config[:foo] == %{value: ~D[2024-08-31], type: :date}
      assert {:ok, config} = Config.validate(%{foo: [:date, :time]}, %{foo: ~T[12:34:56]})
      assert config[:foo] == %{value: ~T[12:34:56], type: :time}

      assert {:ok, config} = Config.validate(%{foo: [:naive_datetime, :datetime]}, %{foo: ~N[2024-08-31 12:34:56]})
      assert config[:foo] == %{value: ~N[2024-08-31 12:34:56], type: :naive_datetime}
      assert {:ok, config} = Config.validate(%{foo: [:naive_datetime, :datetime]}, %{foo: ~U[2024-08-31 12:34:56Z]})
      assert config[:foo] == %{value: ~U[2024-08-31 12:34:56Z], type: :datetime}

      assert {:ok, config} = Config.validate(%{foo: [:uri, :string]}, %{foo: URI.parse("http://example.com")})
      assert config[:foo] == %{value: URI.parse("http://example.com"), type: :uri}
      assert {:ok, config} = Config.validate(%{foo: [:uri, :string]}, %{foo: "http://example.com"})
      assert config[:foo] == %{value: "http://example.com", type: :string}

      assert {:ok, config} = Config.validate(%{foo: [:atom, :function]}, %{foo: :bar})
      assert config[:foo] == %{value: :bar, type: :atom}
      assert {:ok, config} = Config.validate(%{foo: [:atom, :function]}, data = %{foo: fn -> :ok end})
      assert config[:foo] == %{value: data[:foo], type: :function}

      assert {:ok, config} = Config.validate(%{foo: [:string, {:function, 1}]}, %{foo: "bar"})
      assert config[:foo] == %{value: "bar", type: :string}
      assert {:ok, config} = Config.validate(%{foo: [:string, {:function, 1}]}, data = %{foo: fn a -> to_string(a) end})
      assert config[:foo] == %{value: data[:foo], type: {:function, 1}}

      assert {:ok, config} = Config.validate(%{foo: [:boolean, {:function, :boolean}]}, %{foo: true})
      assert config[:foo] == %{value: true, type: :boolean}
      assert {:ok, config} = Config.validate(%{foo: [:boolean, {:function, :boolean}]}, data = %{foo: fn _ -> true end})
      assert config[:foo] == %{value: data[:foo], type: {:function, :boolean}}

      assert {:ok, config} = Config.validate(%{foo: [:integer, {:function, 1, :integer}]}, %{foo: 42})
      assert config[:foo] == %{value: 42, type: :integer}
      data = %{foo: fn a -> String.to_integer(a) end}
      assert {:ok, config} = Config.validate(%{foo: [:integer, {:function, 1, :integer}]}, data)
      assert config[:foo] == %{value: data[:foo], type: {:function, 1, :integer}}

      assert {:ok, config} = Config.validate(%{foo: [:float, nil, {:function, 1, [:float, nil]}]}, %{foo: 3.14})
      assert config[:foo] == %{value: 3.14, type: :float}
      assert {:ok, config} = Config.validate(%{foo: [:float, nil, {:function, 1, [:float, nil]}]}, %{foo: nil})
      assert config[:foo] == %{value: nil, type: nil}
      data = %{foo: fn a -> a end}
      assert {:ok, config} = Config.validate(%{foo: [:float, nil, {:function, 1, [:float, nil]}]}, data)
      assert config[:foo] == %{value: data[:foo], type: {:function, 1, [:float, nil]}}
    end

    test "accepts a keyword list as data" do
      assert {:ok, config} = Config.validate(%{foo: :atom}, foo: :foo)
      assert config[:foo] == %{value: :foo, type: :atom}
    end

    test "raises an error when a key is not in the spec" do
      assert_raise Pax.ConfigError, ~r/invalid key/, fn ->
        Config.validate!(%{foo: :atom}, %{made_up: :foo})
      end

      assert {:error, error} = Config.validate(%{foo: :atom}, %{made_up: :foo})
      assert error =~ "invalid key"
    end

    test "raises an error when a value is not of the correct type" do
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: nil}, %{foo: "nil"}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :atom}, %{foo: "bar"}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :string}, %{foo: :bar}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :boolean}, %{foo: "true"}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :integer}, %{foo: "123"}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :float}, %{foo: "3.14"}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :tuple}, %{foo: [1, 2, 3]}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :list}, %{foo: {1, 2, 3}}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :map}, %{foo: [foo: :bar]}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :module}, %{foo: "Pax"}) end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: :struct}, %{foo: %{field: "value"}})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:struct, TestStruct}}, %{foo: %Date{year: 2024, month: 01, day: 01}})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :date}, %{foo: ~T[12:34:56]}) end
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :time}, %{foo: ~D[2024-08-31]}) end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: :naive_datetime}, %{foo: ~U[2024-08-31 12:34:56Z]})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: :datetime}, %{foo: ~N[2024-08-31 12:34:56]})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: :uri}, %{foo: "not a uri"}) end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: :function}, %{foo: :not_a_function})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:function, 2}}, %{foo: :not_a_function})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:function, :atom}}, %{foo: :not_a_function})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:function, [:atom, :string]}}, %{foo: :not_a_function})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:function, 2, :boolean}}, %{foo: :not_a_function})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: {:function, 2, [:boolean, :integer]}}, %{foo: :not_a_function})
      end
    end

    test "raises an error when value doesn't match any types" do
      assert_raise Pax.ConfigError, ~r/invalid value/, fn -> Config.validate!(%{foo: [nil, :atom]}, %{foo: 42}) end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:string, :boolean]}, %{foo: 42})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:integer, :float]}, %{foo: "42"})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:tuple, :list]}, %{foo: %{1 => 2}})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:map, :module]}, %{foo: [1, 2, 3]})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:struct, nil]}, %{foo: "not a struct"})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:date, :time]}, %{foo: ~U[2024-08-31 12:34:56Z]})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:naive_datetime, :datetime]}, %{foo: ~T[12:34:56]})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:uri, :string]}, %{foo: 123})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [:function, :atom]}, %{foo: 42})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [{:function, 1}, :atom]}, %{foo: fn -> :ok end})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [{:function, :atom}, :atom]}, %{foo: 42})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [{:function, 1, :atom}, :atom]}, %{foo: fn -> 42 end})
      end

      assert_raise Pax.ConfigError, ~r/invalid value/, fn ->
        Config.validate!(%{foo: [{:function, 1, [:atom, nil]}, :atom]}, %{foo: 42})
      end
    end
  end

  describe "fetch/fetch!/get" do
    test "accepts simple values in config data" do
      assert {:ok, config} = Config.validate(%{foo: nil}, %{foo: nil})
      assert Config.fetch(config, :foo) == {:ok, nil}
      assert Config.fetch!(config, :foo) == nil
      assert Config.get(config, :foo) == nil
      assert {:ok, config} = Config.validate(%{foo: :atom}, %{foo: :foo})
      assert Config.fetch(config, :foo) == {:ok, :foo}
      assert Config.fetch!(config, :foo) == :foo
      assert Config.get(config, :foo) == :foo
      assert {:ok, config} = Config.validate(%{foo: :string}, %{foo: "bar"})
      assert Config.fetch(config, :foo) == {:ok, "bar"}
      assert Config.fetch!(config, :foo) == "bar"
      assert Config.get(config, :foo) == "bar"
      assert {:ok, config} = Config.validate(%{foo: :boolean}, %{foo: true})
      assert Config.fetch(config, :foo) == {:ok, true}
      assert Config.fetch!(config, :foo) == true
      assert Config.get(config, :foo) == true
      assert {:ok, config} = Config.validate(%{foo: :integer}, %{foo: 42})
      assert Config.fetch(config, :foo) == {:ok, 42}
      assert Config.fetch!(config, :foo) == 42
      assert Config.get(config, :foo) == 42
      assert {:ok, config} = Config.validate(%{foo: :float}, %{foo: 3.14})
      assert Config.fetch(config, :foo) == {:ok, 3.14}
      assert Config.fetch!(config, :foo) == 3.14
      assert Config.get(config, :foo) == 3.14
      assert {:ok, config} = Config.validate(%{foo: :tuple}, %{foo: {1, 2, 3}})
      assert Config.fetch(config, :foo) == {:ok, {1, 2, 3}}
      assert Config.fetch!(config, :foo) == {1, 2, 3}
      assert Config.get(config, :foo) == {1, 2, 3}
      assert {:ok, config} = Config.validate(%{foo: :list}, %{foo: [1, 2, 3]})
      assert Config.fetch(config, :foo) == {:ok, [1, 2, 3]}
      assert Config.fetch!(config, :foo) == [1, 2, 3]
      assert Config.get(config, :foo) == [1, 2, 3]
      assert {:ok, config} = Config.validate(%{foo: :map}, %{foo: %{foo: "bar"}})
      assert Config.fetch(config, :foo) == {:ok, %{foo: "bar"}}
      assert Config.fetch!(config, :foo) == %{foo: "bar"}
      assert Config.get(config, :foo) == %{foo: "bar"}
      assert {:ok, config} = Config.validate(%{foo: :module}, %{foo: Pax.Config})
      assert Config.fetch(config, :foo) == {:ok, Pax.Config}
      assert Config.fetch!(config, :foo) == Pax.Config
      assert Config.get(config, :foo) == Pax.Config
      assert {:ok, config} = Config.validate(%{foo: :struct}, %{foo: %TestStruct{field: "value"}})
      assert Config.fetch(config, :foo) == {:ok, %TestStruct{field: "value"}}
      assert Config.fetch!(config, :foo) == %TestStruct{field: "value"}
      assert Config.get(config, :foo) == %TestStruct{field: "value"}
      assert {:ok, config} = Config.validate(%{foo: {:struct, TestStruct}}, %{foo: %TestStruct{field: "value"}})
      assert Config.fetch(config, :foo) == {:ok, %TestStruct{field: "value"}}
      assert Config.fetch!(config, :foo) == %TestStruct{field: "value"}
      assert Config.get(config, :foo) == %TestStruct{field: "value"}
      assert {:ok, config} = Config.validate(%{foo: :date}, %{foo: ~D[2024-08-31]})
      assert Config.fetch(config, :foo) == {:ok, ~D[2024-08-31]}
      assert Config.fetch!(config, :foo) == ~D[2024-08-31]
      assert Config.get(config, :foo) == ~D[2024-08-31]
      assert {:ok, config} = Config.validate(%{foo: :time}, %{foo: ~T[12:34:56]})
      assert Config.fetch(config, :foo) == {:ok, ~T[12:34:56]}
      assert Config.fetch!(config, :foo) == ~T[12:34:56]
      assert Config.get(config, :foo) == ~T[12:34:56]
      assert {:ok, config} = Config.validate(%{foo: :naive_datetime}, %{foo: ~N[2024-08-31 12:34:56]})
      assert Config.fetch(config, :foo) == {:ok, ~N[2024-08-31 12:34:56]}
      assert Config.fetch!(config, :foo) == ~N[2024-08-31 12:34:56]
      assert Config.get(config, :foo) == ~N[2024-08-31 12:34:56]
      assert {:ok, config} = Config.validate(%{foo: :datetime}, %{foo: ~U[2024-08-31 12:34:56Z]})
      assert Config.fetch(config, :foo) == {:ok, ~U[2024-08-31 12:34:56Z]}
      assert Config.fetch!(config, :foo) == ~U[2024-08-31 12:34:56Z]
      assert Config.get(config, :foo) == ~U[2024-08-31 12:34:56Z]
      assert {:ok, config} = Config.validate(%{foo: :uri}, %{foo: URI.parse("http://example.com")})
      assert Config.fetch(config, :foo) == {:ok, URI.parse("http://example.com")}
      assert Config.fetch!(config, :foo) == URI.parse("http://example.com")
      assert Config.get(config, :foo) == URI.parse("http://example.com")
      assert {:ok, config} = Config.validate(%{foo: :function}, %{foo: fn -> :bar end})
      assert Config.fetch(config, :foo) == {:ok, :bar}
      assert Config.fetch!(config, :foo) == :bar
      assert Config.get(config, :foo) == :bar
      assert {:ok, config} = Config.validate(%{foo: {:function, 2}}, %{foo: fn a, b -> a + b end})
      assert Config.fetch(config, :foo, [2, 3]) == {:ok, 5}
      assert Config.fetch!(config, :foo, [2, 3]) == 5
      assert Config.get(config, :foo, [2, 3]) == 5
      assert {:ok, config} = Config.validate(%{foo: {:function, :atom}}, %{foo: fn -> :bar end})
      assert Config.fetch(config, :foo) == {:ok, :bar}
      assert Config.fetch!(config, :foo) == :bar
      assert Config.get(config, :foo) == :bar
      assert {:ok, config} = Config.validate(%{foo: {:function, [:atom, :string]}}, %{foo: fn -> :bar end})
      assert Config.fetch(config, :foo) == {:ok, :bar}
      assert Config.fetch!(config, :foo) == :bar
      assert Config.get(config, :foo) == :bar
      assert {:ok, config} = Config.validate(%{foo: {:function, [:atom, :string]}}, %{foo: fn -> "bar" end})
      assert Config.fetch(config, :foo) == {:ok, "bar"}
      assert Config.fetch!(config, :foo) == "bar"
      assert Config.get(config, :foo) == "bar"
      assert {:ok, config} = Config.validate(%{foo: {:function, 2, :boolean}}, %{foo: fn a, b -> a == b end})
      assert Config.fetch(config, :foo, [1, 2]) == {:ok, false}
      assert Config.fetch!(config, :foo, [1, 2]) == false
      assert Config.get(config, :foo, [1, 2]) == false
      assert {:ok, config} = Config.validate(%{foo: {:function, 2, [:boolean, :integer]}}, foo: fn a, b -> a == b end)
      assert Config.fetch(config, :foo, [1, 2]) == {:ok, false}
      assert Config.fetch!(config, :foo, [1, 2]) == false
      assert Config.get(config, :foo, [1, 2]) == false
      assert {:ok, config} = Config.validate(%{foo: {:function, 2, [:boolean, :integer]}}, %{foo: fn a, b -> a + b end})
      assert Config.fetch(config, :foo, [1, 2]) == {:ok, 3}
      assert Config.fetch!(config, :foo, [1, 2]) == 3
      assert Config.get(config, :foo, [1, 2]) == 3
    end

    test "accepts values with optional function" do
      assert {:ok, config} = Config.validate(%{foo: [:integer, {:function, 1, :integer}]}, %{foo: 5})
      assert Config.fetch(config, :foo) == {:ok, 5}
      assert Config.fetch(config, :foo, [1]) == {:ok, 5}
      assert {:ok, config} = Config.validate(%{foo: [:integer, {:function, 1, :integer}]}, %{foo: fn a -> a + 1 end})
      assert Config.fetch(config, :foo, [1]) == {:ok, 2}
    end

    test "accepts values with optional function and optional return type" do
      assert {:ok, config} = Config.validate(%{foo: [:integer, {:function, 1, [:integer, nil]}]}, %{foo: 5})
      assert Config.fetch(config, :foo) == {:ok, 5}
      assert Config.fetch(config, :foo, [1]) == {:ok, 5}

      assert {:ok, config} =
               Config.validate(%{foo: [:integer, {:function, 1, [:integer, nil]}]}, %{foo: fn a -> a + 1 end})

      assert Config.fetch(config, :foo, [1]) == {:ok, 2}

      assert {:ok, config} =
               Config.validate(%{foo: [:integer, {:function, 1, [:integer, nil]}]}, %{foo: fn _ -> nil end})

      assert Config.fetch(config, :foo, [1]) == {:ok, nil}
    end

    test "handles fetching key that does not exist" do
      assert {:ok, config} = Config.validate(%{foo: :atom}, %{foo: :foo})
      assert :error = Config.fetch(config, :bar)
      assert Config.get(config, :bar, :default) == :default
      assert_raise KeyError, fn -> Config.fetch!(config, :bar) end
    end

    test "handles different combinations of args and default" do
      assert {:ok, config} = Config.validate(%{foo: [:atom, {:function, 1, :atom}]}, %{foo: :bar})

      # This only works because we know the data didn't have a function.
      # These are really invalid calls, as it doesn't conform to the spec.
      assert Config.get(config, :foo) == :bar
      assert Config.get(config, :foo, :default) == :bar
      assert Config.get(config, :invalid, :default) == :default

      assert Config.get(config, :foo, [:baz]) == :bar
      assert Config.get(config, :invalid, [:baz]) == nil

      assert Config.get(config, :foo, [:baz], :default) == :bar
      assert Config.get(config, :invalid, [:baz], :default) == :default

      assert {:ok, config} = Config.validate(%{foo: [:atom, {:function, 1, :atom}]}, %{foo: fn a -> a end})
      assert Config.get(config, :foo, [:baz]) == :baz
      assert Config.get(config, :invalid, [:baz]) == nil

      assert Config.get(config, :foo, [:baz], :default) == :baz
      assert Config.get(config, :invalid, [:baz], :default) == :default
    end

    test "raises when not passing correct args for functions" do
      assert {:ok, config} = Config.validate(%{foo: {:function, 2}}, %{foo: fn a, b -> a + b end})
      assert_raise Pax.Config.ArityError, fn -> Config.fetch(config, :foo) end
      assert_raise Pax.Config.ArityError, fn -> Config.fetch(config, :foo, [1]) end
      assert_raise Pax.Config.ArityError, fn -> Config.fetch(config, :foo, [1, 2, 3]) end
      assert_raise Pax.Config.ArityError, fn -> Config.fetch!(config, :foo) end
      assert_raise Pax.Config.ArityError, fn -> Config.fetch!(config, :foo, [1]) end
      assert_raise Pax.Config.ArityError, fn -> Config.fetch!(config, :foo, [1, 2, 3]) end
      assert_raise Pax.Config.ArityError, fn -> Config.get(config, :foo) end
      assert_raise Pax.Config.ArityError, fn -> Config.get(config, :foo, [1]) end
      assert_raise Pax.Config.ArityError, fn -> Config.get(config, :foo, [1, 2, 3]) end
    end

    test "raises when function returns wrong type" do
      assert {:ok, config} = Config.validate(%{foo: {:function, 1, :integer}}, %{foo: fn _ -> :wrong end})
      assert_raise Pax.Config.TypeError, fn -> Config.fetch(config, :foo, [1]) end
      assert_raise Pax.Config.TypeError, fn -> Config.fetch!(config, :foo, [1]) end
      assert_raise Pax.Config.TypeError, fn -> Config.get(config, :foo, [1]) end
    end

    test "raises when invalid config is given" do
      assert_raise ArgumentError, fn -> Config.fetch(%{foo: "bar"}, :foo) end
    end
  end
end