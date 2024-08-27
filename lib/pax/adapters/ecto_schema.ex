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
    id_field = Keyword.get(opts, :id_field, nil)

    %{repo: repo, schema: schema, id_field: id_field}
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

  @impl Pax.Adapter
  def singular_name(_callback_module, %{schema: schema}) do
    Pax.Util.Introspection.name_from_struct(schema)
  end

  @impl Pax.Adapter
  def plural_name(_callback_module, %{schema: schema}) do
    Pax.Util.Introspection.name_from_struct(schema)
    |> Pax.Util.Inflection.pluralize()
  end

  @impl Pax.Adapter
  def count_objects(_callback_module, %{repo: repo, schema: schema}, scope) do
    schema
    |> build_query(scope)
    |> repo.aggregate(:count)
  end

  @doc """
  Returns all objects of the schema.

  TODO: sorting, filtering, etc.
  """
  @impl Pax.Adapter
  def list_objects(_callback_module, %{repo: repo, schema: schema}, scope) do
    schema
    |> build_query(scope)
    |> paginate(scope)
    |> repo.all()
  end

  defp build_query(schema, _scope) do
    from(o in schema)
  end

  defp paginate(query, %{limit: limit, offset: offset}) do
    from q in query, limit: ^limit, offset: ^offset
  end

  defp paginate(query, _scope), do: query

  @impl Pax.Adapter
  def new_object(_callback_module, %{schema: schema}, _params, _uri, _socket) do
    struct(schema)
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
  # TODO: move all of this into the detail page, which will pass the info needed as a scope
  @impl Pax.Adapter
  def get_object(callback_module, %{repo: repo, schema: schema} = opts, params, uri, socket) do
    query =
      from(s in schema)
      |> lookup(callback_module, opts, schema, params, uri, socket)

    repo.one!(query)
  end

  defp lookup(query, callback_module, opts, schema, params, uri, socket) do
    cond do
      # First option: an explicit callback to lookup the object
      function_exported?(callback_module, :pax_lookup, 4) ->
        callback_module.pax_lookup(query, params, uri, socket)

      # Second option: try to find based on the "id" param, and match to our discovered id_field
      lookup = lookup_by_id_field(query, callback_module, opts, params) ->
        lookup

      # Third option: try to match all of the primary keys if they are all present in params
      lookup = lookup_by_primary_keys(query, schema, params) ->
        lookup

      # Fourth option: try to match any of the fields passed in as params
      lookup = lookup_by_fields(query, schema, params) ->
        lookup

      # Fifth option: no lookup possible, so raise an error
      true ->
        raise "Could not figure out how to perform lookup. Please implement a pax_lookup/4 callback in #{inspect(callback_module)}"
    end
  end

  defp lookup_by_id_field(query, callback_module, opts, params) do
    id_field = id_field(callback_module, opts)
    id = Map.get(params, "id")

    if id_field && id do
      from(q in query, where: ^[{id_field, id}])
    end
  end

  defp lookup_by_primary_keys(query, schema, params) do
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

  @impl Pax.Adapter
  def id_field(callback_module, %{schema: schema, id_field: id_field}) do
    cond do
      function_exported?(callback_module, :pax_id_field, 1) ->
        callback_module.pax_id_field()

      id_field != nil ->
        id_field

      true ->
        case schema.__schema__(:primary_key) do
          [primary_key] ->
            primary_key

          # TODO: support composite primary keys without needing a custom callback. This will require using a custom
          #       format for the id_field, such as "col1:col2:col3" or something similar, then also modifying lookup
          #       to handle this format. This assumes primary_keys are always returned in the same order. If not, then
          #       we'll need to encode the column name in the object_id as well.
          primary_keys ->
            raise ArgumentError, """
            Composite Primary Keys are not supported for automatic id_field generation.
            Please implement a pax_object_id/2 callbacks in #{inspect(callback_module)}.
            This means you will also most likely need to implement a pax_object_id/2 callback.
            Got primary keys #{inspect(primary_keys)} for schema #{inspect(schema)}.
            """
        end
    end
  end

  @impl Pax.Adapter
  def object_id(callback_module, opts, object) do
    if function_exported?(callback_module, :pax_object_id, 1) do
      callback_module.pax_object_id(object)
    else
      id_field = id_field(callback_module, opts)
      Map.get(object, id_field)
    end
  end

  @impl Pax.Adapter
  def object_name(_callback_module, %{schema: schema}, object) do
    name = Pax.Util.Introspection.name_from_struct(schema)

    case schema.__schema__(:primary_key) do
      # If there is only one primary key, just append the value of it to the end of the name, e.g. "User 123"
      [primary_key] ->
        value = Map.get(object, primary_key)
        "#{name} #{value}"

      # If there are multiple primary keys, append the names and values of each to the name, e.g. "User id:123 org:456"
      primary_keys ->
        for primary_key <- primary_keys, reduce: name do
          name ->
            value = Map.get(object, primary_key)
            "#{name} #{primary_key}:#{value}"
        end
    end
  end

  @impl Pax.Adapter
  def cast(callback_module, %{schema: schema} = opts, nil, params, fields) do
    # Cast with a default/empty schema struct, e.g. %User{}
    cast(callback_module, opts, struct(schema), params, fields)
  end

  def cast(_callback_module, _opts, object, params, fields) do
    field_names = Enum.map(fields, fn %Pax.Field{name: name} -> name end)
    Ecto.Changeset.cast(object, params, field_names)
  end

  @impl Pax.Adapter
  def create_object(_callback_module, %{repo: repo}, _object, changeset) do
    repo.insert(changeset)
  end

  @impl Pax.Adapter
  def update_object(_callback_module, %{repo: repo}, _object, changeset) do
    repo.update(changeset)
  end
end
