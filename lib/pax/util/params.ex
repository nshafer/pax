defmodule Pax.Util.Params do
  @doc """
  Builds a URL or path with the given query parameters.

  Accepts a URL or path and a keyword list or map of parameters. Handles merging, overriding, and removing
  parameters, including support for complex values (lists, maps and keyword lists as supported by `Plug.Conn.Query/2`).

  If a value of `[value: v, default: d]` option is given, the parameter is omitted if `v == d`. In this format,
  `:value` must come first, otherwise it is treated as a list. If you must provide a list with `{:value, _something}`,
  then either make sure it's not first, or pass it as: `foo: [value: [value: "bar"]]`.

  ## Examples

      iex> with_params("/test")
      "/test"

      iex> with_params("/test", foo: "bar")
      "/test?foo=bar"

      iex> with_params("/test", foo: [1, 2, 3])
      "/test?foo[]=1&foo[]=2&foo[]=3"

      iex> with_params("/test?foo=bar", foo: nil)
      "/test"

      iex> with_params("/test", foo: [value: "bar", default: "bar"])
      "/test"

      iex> with_params("/test", foo: [value: "baz", default: "bar"])
      "/test?foo=baz"

  """
  def with_params(url_or_path, params \\ [])

  def with_params(url_or_path, []), do: url_or_path

  def with_params(url_or_path, params) do
    url = URI.parse(url_or_path)

    query =
      url
      |> maybe_decode_query()
      |> set_params(params)
      |> normalize_params()
      |> sort_params()
      |> Plug.Conn.Query.encode()

    if query == "" do
      %URI{url | query: nil}
      |> URI.to_string()
    else
      %URI{url | query: query}
      |> URI.to_string()
    end
  end

  defp maybe_decode_query(%URI{} = url) do
    case url.query do
      nil -> %{}
      query -> Plug.Conn.Query.decode(query)
    end
  end

  defp set_params(query_map, params) do
    for {key, value} <- params, reduce: query_map do
      query_map -> add_or_remove(query_map, to_string(key), value)
    end
  end

  defp add_or_remove(query_map, key, nil) do
    Map.delete(query_map, to_string(key))
  end

  defp add_or_remove(query_map, key, opts) when is_list(opts) or is_map(opts) do
    {value, default} = get_value_and_default(opts)

    if value != default do
      Map.put(query_map, key, value)
    else
      Map.delete(query_map, key)
    end
  end

  defp add_or_remove(query_map, key, value) when is_binary(value) do
    Map.put(query_map, key, value)
  end

  defp add_or_remove(query_map, key, value) when is_atom(value) or is_integer(value) or is_float(value) do
    Map.put(query_map, key, to_string(value))
  end

  defp add_or_remove(_query_map, key, value) do
    raise ArgumentError, "invalid value #{inspect(value)} for param #{inspect(key)}"
  end

  # Detect special keyword list format with `:value` and optional `:default`.
  defp get_value_and_default([{:value, value}]) do
    {value, nil}
  end

  defp get_value_and_default([{:value, value}, {:default, default}]) do
    {value, default}
  end

  # Otherwise it's a list or map of params and no default is provided.
  defp get_value_and_default(opts), do: {opts, nil}

  defp normalize_params(params) do
    for {k, v} <- params do
      {to_string(k), v}
    end
  end

  defp sort_params(params) do
    Enum.sort(params, fn {k1, _}, {k2, _} -> k1 <= k2 end)
  end
end
