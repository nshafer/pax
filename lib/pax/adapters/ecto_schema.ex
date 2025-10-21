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
    %{
      repo: Keyword.get(opts, :repo),
      schema: Keyword.get(opts, :schema)
    }
  end

  @impl Pax.Adapter
  def config_spec(_opts) do
    %{
      repo: [:module, {:function, 1, :module}],
      schema: [:module, {:function, 1, :module}]
    }
  end

  @impl Pax.Adapter
  def merge_config(opts, config, socket) do
    opts = %{
      repo: Pax.Config.get(config, :repo, [socket], opts.repo),
      schema: Pax.Config.get(config, :schema, [socket], opts.schema)
    }

    # Ensure that the repo and schema are provided either via init opts or config
    if opts.repo && opts.schema do
      opts
    else
      raise """
      Missing required configuration for EctoSchema adapter. You must provide a `repo` and `schema` in the config.

      Examples:
          def pax_adapter(_socket) do
            {Pax.Adapters.EctoSchema, repo: MyApp.Repo, schema: MyApp.MySchema}
          end

          def pax_config(socket) do
            [
              adapter: [
                repo: MyApp.Repo,
                schema: MyApp.MySchema
              ]
            ]
          end
      """
    end
  end

  @impl Pax.Adapter
  def default_fields(%{schema: schema}) do
    for field_name <- schema.__schema__(:fields),
        schema_type = schema.__schema__(:type, field_name),
        {:ok, field_type} = schema_to_field_type(schema, schema_type) do
      {field_name, field_type}
    end
  end

  @doc """
  Returns the field type for the given field name.
  """
  @impl Pax.Adapter
  def field_type(%{schema: schema}, field_name) do
    schema_type = schema.__schema__(:type, field_name)

    if schema_type do
      schema_to_field_type(schema, schema_type)
    else
      {:error, "Unknown field #{inspect(field_name)} for schema #{inspect(schema)}"}
    end
  end

  @impl Pax.Adapter
  def singular_name(%{schema: schema}) do
    Pax.Util.Introspection.name_from_struct(schema)
  end

  @impl Pax.Adapter
  def plural_name(%{schema: schema}) do
    Pax.Util.Introspection.name_from_struct(schema)
    |> Pax.Util.Inflection.pluralize()
  end

  @impl Pax.Adapter
  def count_objects(%{repo: repo, schema: schema}, scope) do
    schema
    |> build_query(scope)
    |> repo.aggregate(:count)
  end

  @doc """
  Returns all objects of the schema.

  TODO: advanced filtering that allows different types of queries/operators
  """
  @impl Pax.Adapter
  def list_objects(%{repo: repo, schema: schema}, scope) do
    schema
    |> build_query(scope)
    |> sort(scope)
    |> paginate(scope)
    |> filter_where(scope)
    |> repo.all()
  end

  defp build_query(schema, _scope) do
    from(o in schema)
  end

  defp sort(query, %{order_by: order_by}) do
    from q in query, order_by: ^order_by
  end

  defp sort(query, _scope), do: query

  defp paginate(query, %{limit: limit, offset: offset}) do
    from q in query, limit: ^limit, offset: ^offset
  end

  defp paginate(query, %{limit: limit}) do
    from q in query, limit: ^limit
  end

  defp paginate(query, _scope), do: query

  defp filter_where(query, %{where: where}) do
    from q in query, where: ^where
  end

  defp filter_where(query, _scope), do: query

  @impl Pax.Adapter
  def new_object(%{schema: schema}, _socket) do
    struct(schema)
  end

  @doc """
  Gets the object based on the lookup map

  TODO: advanced filtering
  """
  @impl Pax.Adapter
  def get_object(%{repo: repo, schema: schema}, lookup, scope, _socket) do
    schema
    |> build_query(scope)
    |> filter_where(scope)
    |> filter_lookup(lookup)
    |> repo.one!()
  end

  defp filter_lookup(query, lookup) do
    from q in query, where: ^Map.to_list(lookup)
  end

  @impl Pax.Adapter
  def id_fields(%{schema: schema}) do
    schema.__schema__(:primary_key)
  end

  @impl Pax.Adapter
  def object_ids(_opts, _object), do: nil

  @impl Pax.Adapter
  def object_name(%{schema: schema}, object) do
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
  def change_object(_opts, object, params, fields) do
    mutable_fields = Pax.Field.mutable_fields(fields)
    mutable_field_names = Enum.map(mutable_fields, fn %Pax.Field{name: name} -> name end)

    object
    |> Ecto.Changeset.cast(params, mutable_field_names)
    |> Pax.Field.validate_required(mutable_fields)
  end

  @impl Pax.Adapter
  def create_object(%{repo: repo}, _object, changeset, _params) do
    repo.insert(changeset)
  end

  @impl Pax.Adapter
  def update_object(%{repo: repo}, _object, changeset, _params) do
    repo.update(changeset)
  end
end
