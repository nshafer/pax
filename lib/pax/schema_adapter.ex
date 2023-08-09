defmodule Pax.SchemaAdapter do
  @behaviour Pax.Adapter
  import Ecto.Query

  @impl Pax.Adapter
  def init(_module, opts) do
    repo = Keyword.get(opts, :repo) || raise "repo is required"
    schema = Keyword.get(opts, :schema) || raise "schema is required"

    %{repo: repo, schema: schema}
  end

  @impl Pax.Adapter
  def list_objects(_module, %{repo: repo, schema: schema}, _params, _uri, _socket) do
    repo.all(schema)
  end

  @impl Pax.Adapter
  def get_object(module, %{repo: repo, schema: schema}, params, uri, _socket) do
    query =
      from(s in schema)
      |> lookup(module, schema, params, uri)

    repo.one(query)
  end

  defp lookup(query, module, schema, params, uri) do
    cond do
      function_exported?(module, :lookup, 4) ->
        module.lookup(query, schema, params, uri)

      lookup = lookup_by_primary_key(query, schema, params) ->
        lookup

      lookup = lookup_by_fields(query, schema, params) ->
        lookup

      true ->
        nil
    end
  end

  defp lookup_by_primary_key(query, schema, params) do
    primary_keys = schema.__schema__(:primary_key)

    if Enum.all?(primary_keys, &Map.has_key?(params, to_string(&1))) do
      filters = Enum.map(primary_keys, &{&1, Map.get(params, to_string(&1))})
      from(q in query, where: ^filters)
    end
  end

  defp lookup_by_fields(query, schema, params) do
    fields = schema.__schema__(:fields)
    matched_fields = Enum.filter(fields, &Map.has_key?(params, to_string(&1)))
    filters = Enum.map(matched_fields, &{&1, Map.get(params, to_string(&1))})
    from(q in query, where: ^filters)
  end
end
