defmodule Pax.ExceptionsTest do
  use ExUnit.Case, async: true

  alias Pax.Config.TypeError

  describe "Pax.Config.TypeError" do
    test "explains a single expected type" do
      explanations = [
        {nil, "nil"},
        {:atom, "an atom"},
        {:string, "a string"},
        {:boolean, "a boolean"},
        {:integer, "an integer"},
        {:float, "a float"},
        {:tuple, "a tuple"},
        {:list, "a list"},
        {:map, "a map"},
        {:module, "a module"},
        {:struct, "a struct"},
        {{:struct, URI}, "a Elixir.URI struct"},
        {:date, "a Date struct"},
        {:time, "a Time struct"},
        {:naive_datetime, "a NaiveDateTime struct"},
        {:datetime, "a DateTime struct"},
        {:uri, "a URI struct"},
        {:function, "a function"},
        {{:function, 2}, "a function with 2 arity"},
        {{:function, :string}, "a function that returns a string"},
        {{:function, [:string, nil]}, "a function that returns a string or nil"},
        {{:function, 1, :integer}, "a function with 1 arity that returns an integer"},
        {{:function, 1, [:integer, :float]}, "a function with 1 arity that returns an integer or a float"},
        {:unknown, "a :unknown"}
      ]

      for {type, explanation} <- explanations do
        error = TypeError.exception(key: :foo, value: 42, type: type)
        assert error.message == "invalid type given for foo: 42, should be #{explanation}"
      end
    end

    test "lists every expected type" do
      error = TypeError.exception(key: :foo, value: "bar", types: [:integer, {:function, 1, :integer}])

      assert error.message == """
             invalid type given for foo: "bar"

             Should be one of the following:
             - an integer
             - a function with 1 arity that returns an integer
             """

      assert error.types == [:integer, {:function, 1, :integer}]
      assert error.value == "bar"
    end

    test "explains values returned from functions" do
      error = TypeError.exception(key: :foo, value: 42, type: :string, is_return: true)
      assert error.message == "invalid type returned from function for foo: 42, should be a string"
    end

    test "only includes the preamble when no types are given" do
      error = TypeError.exception(key: :foo, value: 42)
      assert error.message == "invalid type given for foo: 42"
    end
  end

  describe "Pax.Assets.NotFoundError" do
    test "is a 404" do
      assert Plug.Exception.status(%Pax.Assets.NotFoundError{message: "Asset not found"}) == 404
    end
  end

  describe "Pax.Admin.ResourceNotFoundError" do
    test "names the resource, and the section when given" do
      error = Pax.Admin.ResourceNotFoundError.exception(resource: "books")
      assert error.message == "resource books not found"
      assert error.resource == "books"
      assert error.section == nil

      error = Pax.Admin.ResourceNotFoundError.exception(section: "library", resource: "books")
      assert error.message == "resource books not found in section library"
      assert error.section == "library"
      assert Plug.Exception.status(error) == 404
    end
  end
end
