defmodule Pax.Util.URITest do
  use ExUnit.Case, async: true

  import Pax.Util.URI

  doctest Pax.Util.URI

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

    test "can add list params with simple value" do
      assert with_params("/test", page: [1, 2, 3]) == "/test?page[]=1&page[]=2&page[]=3"
      assert with_params("/test", page: [1, 2, 3], foo: "bar") == "/test?foo=bar&page[]=1&page[]=2&page[]=3"

      assert with_params("/test", page: [1, 2, 3], foo: [:bar, :baz]) ==
               "/test?foo[]=bar&foo[]=baz&page[]=1&page[]=2&page[]=3"
    end

    test "can add list params with complex value" do
      assert with_params("/test", page: [value: [1, 2, 3]]) == "/test?page[]=1&page[]=2&page[]=3"
      assert with_params("/test", page: [value: [1, 2, 3], default: [1, 2, 3]]) == "/test"
      assert with_params("/test", page: [value: [2, 3, 4], default: [1, 2, 3]]) == "/test?page[]=2&page[]=3&page[]=4"
    end

    test "list values can be empty" do
      assert with_params("/test", page: []) == "/test"
      assert with_params("/test", page: [value: []]) == "/test"
      assert with_params("/test", page: [value: [], default: []]) == "/test"
    end

    test "can add map params with simple value" do
      assert with_params("/test", filter: %{name: "bob"}) == "/test?filter[name]=bob"
      assert url = with_params("/test", filter: %{name: "bob", age: 30})
      assert url == "/test?filter[name]=bob&filter[age]=30" or url == "/test?filter[age]=30&filter[name]=bob"
    end

    test "can add map params with complex value" do
      assert with_params("/test", filter: [value: %{name: "bob"}]) == "/test?filter[name]=bob"
      assert with_params("/test", filter: [value: %{name: "bob"}, default: %{name: "bob"}]) == "/test"

      assert with_params("/test", filter: [value: %{name: "bob"}, default: %{name: "alice"}]) ==
               "/test?filter[name]=bob"
    end

    test "can add keyword params with simple value" do
      assert with_params("/test", filter: [name: "bob"]) == "/test?filter[name]=bob"
      assert with_params("/test", filter: [name: "bob", age: 30]) == "/test?filter[name]=bob&filter[age]=30"
    end

    test "can add keyword params with complex value" do
      assert with_params("/test", filter: [value: [name: "bob"]]) == "/test?filter[name]=bob"
      assert with_params("/test", filter: [value: [name: "bob"], default: [name: "bob"]]) == "/test"

      assert with_params("/test", filter: [value: [name: "bob"], default: [name: "alice"]]) ==
               "/test?filter[name]=bob"
    end

    test "can add params to url with existing params" do
      assert with_params("/test?search=qwer", page: 1) == "/test?page=1&search=qwer"

      assert with_params("/test?page=2", search: "asdf", "filter[name]": "bob") ==
               "/test?filter%5Bname%5D=bob&page=2&search=asdf"
    end

    test "can override existing params" do
      assert with_params("/test?page=2", page: 1) == "/test?page=1"
      assert with_params("/test?foo=bar", foo: "baz") == "/test?foo=baz"
      assert with_params("/test?foo=bar", foo: [:baz, :qwop]) == "/test?foo[]=baz&foo[]=qwop"
      assert with_params("/test?foo[]=baz&foo[]=qwop", foo: :bar) == "/test?foo=bar"
      assert with_params("/test?foo=bar", foo: nil) == "/test"
      assert with_params("/test?foo=bar", foo: [value: %{bar: "baz"}]) == "/test?foo[bar]=baz"
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

  describe "with_params/2 edge cases" do
    test "accepts a %URI{}" do
      assert with_params(URI.parse("/test?foo=bar"), baz: "qux") == "/test?baz=qux&foo=bar"
      assert with_params(%URI{path: "/test", query: nil}, page: 2) == "/test?page=2"
    end

    test "accepts a map of params" do
      assert with_params("/test", %{foo: "bar"}) == "/test?foo=bar"
    end

    test "converts atom, integer and float values to strings" do
      assert with_params("/test", a: :atom, b: 1, c: 1.5) == "/test?a=atom&b=1&c=1.5"
    end

    test "keeps the host of full URLs" do
      assert with_params("https://example.com/test?foo=bar", foo: "baz") == "https://example.com/test?foo=baz"
    end

    test "raises on values that can't be encoded" do
      assert_raise ArgumentError, ~r/invalid value {:tuple} for param "foo"/, fn ->
        with_params("/test", foo: {:tuple})
      end
    end
  end

  describe "encode_query_string/1" do
    test "returns nil for nil or a URI without a query" do
      assert encode_query_string(nil) == nil
      assert encode_query_string(%URI{path: "/test"}) == nil
    end

    test "escapes everything but unreserved characters" do
      assert encode_query_string("page=2&sort=-name") == "page%3D2%26sort%3D-name"
      assert encode_query_string(URI.parse("/test?a=b c")) == "a%3Db%20c"
      assert encode_query_string("Az09~_-.") == "Az09~_-."
    end
  end

  describe "decode_query_string/1" do
    test "returns nil for nil or a URI without a query" do
      assert decode_query_string(nil) == nil
      assert decode_query_string(%URI{path: "/test"}) == nil
    end

    test "reverses encode_query_string/1" do
      assert decode_query_string("page%3D2%26sort%3D-name") == "page=2&sort=-name"
      assert decode_query_string(%URI{query: "a%3Db%20c"}) == "a=b c"
    end
  end

  describe "append_query/2" do
    test "returns the uri unchanged when the query is nil" do
      assert append_query("/test", nil) == "/test"
      assert append_query(%URI{path: "/test"}, nil) == %URI{path: "/test"}
    end

    test "appends a query to a string path" do
      assert append_query("/test", "page=2") == "/test?page=2"
      assert append_query("/test?foo=bar", "page=2") == "/test?foo=bar&page=2"
    end

    test "appends a query to a %URI{}" do
      assert append_query(%URI{path: "/test"}, "page=2") == %URI{path: "/test", query: "page=2"}
    end
  end
end
