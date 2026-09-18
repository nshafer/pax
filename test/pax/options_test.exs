defmodule Pax.OptionsTest do
  use ExUnit.Case, async: true

  alias Pax.Options

  doctest Pax.Options

  @schema NimbleOptions.new!(limit: [type: :integer], placement: [type: {:or, [:atom, {:list, :atom}]}])

  describe "validate!/3" do
    test "returns valid options, with defaults" do
      assert Options.validate!([limit: 10, placement: :top], @schema, "plugin MyPlugin") == [limit: 10, placement: :top]
      assert Options.validate!([], @schema, "plugin MyPlugin") == []
      assert Options.validate!([], [], "plugin MyPlugin") == []

      assert Options.validate!([limit: 1], [limit: [type: :integer], page: [type: :integer, default: 1]], "x") == [
               page: 1,
               limit: 1
             ]
    end

    test "accepts a raw schema as well as a compiled one" do
      assert Options.validate!([limit: 10], [limit: [type: :integer]], "plugin MyPlugin") == [limit: 10]
    end

    test "raises on unknown options, listing the valid ones" do
      assert_raise ArgumentError,
                   "Invalid options for plugin MyPlugin: unknown options [:per_page], valid options are: [:limit, :placement]",
                   fn -> Options.validate!([per_page: 10], @schema, "plugin MyPlugin") end

      assert_raise ArgumentError,
                   "Invalid options for field type MyType: unknown options [:limit], valid options are: []",
                   fn ->
                     Options.validate!([limit: 10], [], "field type MyType")
                   end
    end

    test "raises on options with the wrong type" do
      assert_raise ArgumentError, ~r/^Invalid options for plugin MyPlugin: invalid value for :limit option/, fn ->
        Options.validate!([limit: "10"], @schema, "plugin MyPlugin")
      end
    end

    test "raises when the options aren't a keyword list" do
      assert_raise ArgumentError, "Invalid options for plugin MyPlugin, expected a keyword list, got: [:limit]", fn ->
        Options.validate!([:limit], @schema, "plugin MyPlugin")
      end

      # Built at runtime, so the type checker does not statically reject the call
      opts = Map.new(limit: 10)

      assert_raise ArgumentError, ~r/expected a keyword list, got: %{limit: 10}/, fn ->
        Options.validate!(opts, @schema, "plugin MyPlugin")
      end
    end

    test "raises when the schema isn't a NimbleOptions schema" do
      schema = Map.new(limit: :integer)

      assert_raise ArgumentError,
                   "Invalid options schema for plugin MyPlugin, expected a NimbleOptions schema, got: %{limit: :integer}",
                   fn -> Options.validate!([limit: 10], schema, "plugin MyPlugin") end
    end
  end
end
