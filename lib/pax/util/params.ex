defmodule Pax.Util.Params do
  def with_params(url_or_path, params \\ [])

  def with_params(url_or_path, []), do: url_or_path

  def with_params(url_or_path, params) do
    url = URI.parse(url_or_path)

    params =
      url
      |> maybe_decode_query()
      |> set_params(params)
      |> normalize_params()
      |> sort_params()
      |> Enum.into(%{})

    if map_size(params) > 0 do
      query = URI.encode_query(params)

      %URI{url | query: query}
      |> URI.to_string()
    else
      %URI{url | query: nil}
      |> URI.to_string()
    end
  end

  defp maybe_decode_query(%URI{} = url) do
    case url.query do
      nil -> %{}
      query -> URI.decode_query(query)
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

  defp add_or_remove(query_map, key, opts) when is_list(opts) do
    value = get_value(opts)
    default = Keyword.get(opts, :default)

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

  defp get_value(add_or_remove) when is_list(add_or_remove) do
    case Keyword.fetch(add_or_remove, :value) do
      {:ok, value} -> value
      :error -> raise ArgumentError, "Must specify bare value or keyword list with :value key"
    end
  end

  defp get_value(add_or_remove), do: add_or_remove

  defp normalize_params(params) do
    for {k, v} <- params do
      {to_string(k), v}
    end
  end

  defp sort_params(params) do
    Enum.sort(params, fn {k1, _}, {k2, _} -> k1 <= k2 end)
  end
end
