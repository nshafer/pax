defmodule Pax.UtilTest do
  use ExUnit.Case, async: true

  import Pax.Util.Params

  describe "Params" do
    test "can call with path and no params" do
      assert with_params("/") == "/"
    end

    test "can add params with simple value" do
      assert with_params("/test", foo: "bar") == "/test?foo=bar"
      assert with_params("/test", foo: "bar", baz: "qwop") == "/test?baz=qwop&foo=bar"
    end

    test "can add params with a complex value" do
      assert with_params("/test", page: [value: 1]) == "/test?page=1"
      assert with_params("/test", page: [value: 1, default: 1]) == "/test"
      assert with_params("/test", page: [value: 2, default: 1]) == "/test?page=2"
    end

    test "can add params to url with existing params" do
      assert with_params("/test?search=qwer", page: 1) == "/test?page=1&search=qwer"

      assert with_params("/test?page=2", search: "asdf", "filter[name]": "bob") ==
               "/test?filter%5Bname%5D=bob&page=2&search=asdf"
    end

    test "error is thrown if invalid param" do
      assert_raise(ArgumentError, fn ->
        with_params("/test", page: [not_value: 1])
      end)

      assert_raise(ArgumentError, fn ->
        with_params("/test", page: [1, 2, 3])
      end)

      assert_raise(ArgumentError, fn ->
        with_params("/test", page: %{foo: "bar"})
      end)
    end

    test "can override existing params" do
      assert with_params("/test?page=2", page: 1) == "/test?page=1"
    end

    test "can remove simple params" do
      assert with_params("/test", foo: nil) == "/test"
      assert with_params("/test?foo=asdf", foo: nil) == "/test"
    end

    test "can remove lists of params" do
      assert with_params("/test", foo: nil, bar: nil) == "/test"
      assert with_params("/test?foo=asdf", foo: nil, bar: nil) == "/test"
      assert with_params("/test?foo=asdf&bar=qwer", foo: nil, bar: nil) == "/test"
      assert with_params("/test?foo=asdf&bar=qwer&baz=zxcv", foo: nil, bar: nil) == "/test?baz=zxcv"
    end
  end
end
