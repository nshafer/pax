defmodule Pax.Adapters.EctoSchema do
  @behaviour Pax.Adapter
  import Ecto.Query

  defp schema_to_field_type(schema, schema_type) do
    case schema_type do
      :id -> {:ok, :integer}
      :binary_id -> {:ok, :string}
      :integer -> {:ok, :integer}
      :float -> {:ok, :float}
      :boolean -> {:ok, :boolean}
      :string -> {:ok, :string}
      :binary -> {:error, ":binary fields are not supported"}
      {:array, _inner_type} -> {:error, "TODO: arrays"}
      :map -> {:error, "TODO: maps"}
      {:map, _inner_type} -> {:error, "TODO: maps"}
      :decimal -> {:error, "TODO: decimals"}
      :date -> {:ok, :date}
      :time -> {:ok, :time}
      :time_usec -> {:ok, :time}
      :naive_datetime -> {:ok, :datetime}
      :naive_datetime_usec -> {:ok, :datetime}
      :utc_datetime -> {:ok, :datetime}
      :utc_datetime_usec -> {:ok, :datetime}
      Ecto.UUID -> {:ok, :string}
      Ecto.Enum -> {:error, "TODO: Enums"}
      type -> {:error, invalid_type(type, schema)}
    end
  end

  defp invalid_type(type, schema) do
    """
    Unknown schema type #{inspect(type)} in schema #{inspect(schema)}.

    If you are using a custom type, you must create a custom Type module that implements the Pax.Field behaviour.
    """
  end

  @impl Pax.Adapter
  def init(_callback_module, opts) do
    repo = Keyword.get(opts, :repo) || raise "repo is required"
    schema = Keyword.get(opts, :schema) || raise "schema is required"

    %{repo: repo, schema: schema}
  end

  @impl Pax.Adapter
  def default_index_fields(_callback_module, %{schema: schema}) do
    for field_name <- schema.__schema__(:fields),
        schema_type = schema.__schema__(:type, field_name),
        {:ok, field_type} = schema_to_field_type(schema, schema_type) do
      {field_name, field_type}
    end
  end

  @impl Pax.Adapter
  def default_detail_fieldsets(callback_module, opts) do
    [default: default_index_fields(callback_module, opts)]
  end

  @doc """
  Returns the field type for the given field name.
  """
  @impl Pax.Adapter
  def field_type(_callback_module, %{schema: schema}, field_name) do
    schema_type = schema.__schema__(:type, field_name)

    if schema_type do
      schema_to_field_type(schema, schema_type)
    else
      {:error, "Unknown field #{inspect(field_name)} for schema #{inspect(schema)}"}
    end
  end

  @doc """
  Returns all objects of the schema.

  TODO: pagination, sorting, filtering, etc.
  """
  @impl Pax.Adapter
  def list_objects(_callback_module, %{repo: repo, schema: schema}, _params, _uri, _socket) do
    repo.all(schema)
  end

  @doc """
  Will get the object by querying the schema with the following lookups, in order of precedence:application

  ## 1. Module callback `lookup/4`

  If the module defines a callback `lookup/4`, it will be called with the query, params, uri and socket and expects
  a query in return. For example:

        def lookup(query, %{"id" => id}, _uri, _socket) do
          from q in query, where: q.id == ^id
        end

  ## 2. Primary key lookup

  If the params contain all the primary keys of the schema, it will be looked up by those. For example, if the schema
  has a primary key of `id` and the params contain `id`, it will be looked up by `id`. If the schema has a composite
  primary key of `id` and `slug` and the params contain `id` and `slug`, it will be looked up by `id` and `slug`.

  ## 3. Field lookup

  If the params contain any of the fields of the schema, it will be looked up by those. For example, if the schema
  has a field of `slug` and the params contain `slug`, it will be looked up by `slug`. It will lookup all matching
  fields provided in the params, so extra fields are added (such as in the query string) that don't match, then the
  lookup will fail.

  This will raise Ecto.NoResultsError if no object is found, and Ecto.MultipleResultsError if more than one object is
  found. The former will be converted to a 404 error by :phoenix_ecto, but the latter will be raised as a 500 error.

  """
  @impl Pax.Adapter
  def get_object(callback_module, %{repo: repo, schema: schema}, params, uri, socket) do
    query =
      from(s in schema)
      |> lookup(callback_module, schema, params, uri, socket)

    repo.one!(query)
  end

  defp lookup(query, callback_module, schema, params, uri, socket) do
    cond do
      function_exported?(callback_module, :lookup, 4) ->
        callback_module.lookup(query, params, uri, socket)

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
