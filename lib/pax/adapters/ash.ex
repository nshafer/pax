if Code.ensure_loaded?(Ash) and Code.ensure_loaded?(AshPhoenix.Form) do
  defmodule Pax.Adapters.Ash do
    @opts_schema NimbleOptions.new!(
                   resource: [
                     type: :atom,
                     doc: "The Ash resource of the objects. Required, here or in the adapter config."
                   ],
                   domain: [
                     type: :atom,
                     doc: "The Ash domain to call. Defaults to the one the resource names."
                   ],
                   read_action: [
                     type: :atom,
                     doc: "Defaults to the resource's primary read action."
                   ],
                   create_action: [
                     type: :atom,
                     doc: "Defaults to the resource's primary create action."
                   ],
                   update_action: [
                     type: :atom,
                     doc: "Defaults to the resource's primary update action."
                   ]
                 )

    @moduledoc """
    A Pax.Adapter for Ash resources. It introspects fields, names and primary keys from the resource, builds an
    `Ash.Query` from the criteria, and uses `AshPhoenix.Form` for the new and edit pages.

        def pax_adapter(_socket) do
          {Pax.Adapters.Ash, resource: MyApp.Catalog.Album}
        end

    This module is only compiled when `:ash` and `:ash_phoenix` are available, so a host without them is
    unaffected. Both are optional dependencies of Pax.

    ## Options

    #{NimbleOptions.docs(@opts_schema)}

    ## The actor and the tenant

    Every Ash call takes an `actor`, and that is what `Ash.Policy.Authorizer` reads. A resource that is
    forbid-by-default answers `[]` to a call by nobody, so an adapter that cannot see who is asking cannot read a
    row. Neither the actor nor the tenant is an option, because neither is fixed when the adapter is initialized:
    both are resolved per call from the config.

        def pax_config(_socket) do
          [adapter: [actor: & &1.assigns.current_user]]
        end

    Both accept a literal or a function of the socket, and both default to `nil`.

    ## Field types

    | Ash type | Pax field type |
    | --- | --- |
    | `:string`, `:ci_string`, `:uuid`, `:uuid_v7` | `:string` |
    | `:integer` | `:integer` |
    | `:float` | `:float` |
    | `:boolean` | `:boolean` |
    | `:date` | `:date` |
    | `:time` | `:time` |
    | `:utc_datetime`, `:utc_datetime_usec`, `:naive_datetime` | `:datetime` |

    Decimals, maps and atoms constrained with `one_of` are not supported yet, the same as in
    `Pax.Adapters.EctoSchema`. They need Pax field types that do not exist yet.
    """

    @behaviour Pax.Adapter

    @impl Pax.Adapter
    def init(_callback_module, opts) do
      opts = Pax.Options.validate!(opts, @opts_schema, "adapter #{inspect(__MODULE__)}")

      %{
        resource: opts[:resource],
        domain: opts[:domain],
        read_action: opts[:read_action],
        create_action: opts[:create_action],
        update_action: opts[:update_action]
      }
    end

    @impl Pax.Adapter
    def config_spec(_opts) do
      %{
        resource: [:module, {:function, 1, :module}],
        domain: [:module, {:function, 1, :module}],
        read_action: [:atom, {:function, 1, :atom}],
        create_action: [:atom, {:function, 1, :atom}],
        update_action: [:atom, {:function, 1, :atom}],
        actor: [{:function, 1, :any}, :any],
        tenant: [{:function, 1, :any}, :any]
      }
    end

    @impl Pax.Adapter
    def merge_config(opts, config, socket) do
      opts = %{
        resource: Pax.Config.get(config, :resource, [socket], opts.resource),
        domain: Pax.Config.get(config, :domain, [socket], opts.domain),
        read_action: Pax.Config.get(config, :read_action, [socket], opts.read_action),
        create_action: Pax.Config.get(config, :create_action, [socket], opts.create_action),
        update_action: Pax.Config.get(config, :update_action, [socket], opts.update_action)
      }

      if opts.resource do
        opts
      else
        raise """
        Missing required configuration for the Ash adapter. You must provide a `resource` in the config.

        Examples:
            def pax_adapter(_socket) do
              {Pax.Adapters.Ash, resource: MyApp.Catalog.Album}
            end

            def pax_config(socket) do
              [
                adapter: [
                  resource: MyApp.Catalog.Album
                ]
              ]
            end
        """
      end
    end

    @impl Pax.Adapter
    def default_fields(%{resource: resource}) do
      # Primary keys and attributes the resource generates, such as timestamps, are shown but not editable.
      for attribute <- Ash.Resource.Info.public_attributes(resource),
          {:ok, field_type} <- [ash_to_field_type(resource, attribute.type, attribute.constraints)] do
        if immutable_attribute?(resource, attribute) do
          {attribute.name, field_type, immutable: true}
        else
          {attribute.name, field_type, required: not attribute.allow_nil?}
        end
      end
    end

    defp immutable_attribute?(resource, attribute) do
      attribute.name in Ash.Resource.Info.primary_key(resource) or not attribute.writable? or
        attribute.generated?
    end

    @impl Pax.Adapter
    def field_type(%{resource: resource}, field_name) do
      case Ash.Resource.Info.attribute(resource, field_name) do
        nil -> {:error, "Unknown field #{inspect(field_name)} for resource #{inspect(resource)}"}
        attribute -> ash_to_field_type(resource, attribute.type, attribute.constraints)
      end
    end

    defp ash_to_field_type(resource, type, constraints) do
      case Ash.Type.get_type(type) do
        Ash.Type.String -> {:ok, :string}
        Ash.Type.CiString -> {:ok, :string}
        Ash.Type.UUID -> {:ok, :string}
        Ash.Type.UUIDv7 -> {:ok, :string}
        Ash.Type.Integer -> {:ok, :integer}
        Ash.Type.Float -> {:ok, :float}
        Ash.Type.Boolean -> {:ok, :boolean}
        Ash.Type.Date -> {:ok, :date}
        Ash.Type.Time -> {:ok, :time}
        Ash.Type.UtcDatetime -> {:ok, :datetime}
        Ash.Type.UtcDatetimeUsec -> {:ok, :datetime}
        Ash.Type.NaiveDatetime -> {:ok, :datetime}
        Ash.Type.Decimal -> {:error, "TODO: decimals"}
        Ash.Type.Map -> {:error, "TODO: maps"}
        Ash.Type.Keyword -> {:error, "TODO: maps"}
        Ash.Type.Atom -> atom_field_type(constraints)
        {:array, _inner} -> {:error, "TODO: arrays"}
        other -> {:error, invalid_type(other, resource)}
      end
    end

    # An atom constrained to a set of values is the same idea as an Ecto.Enum, and wants the same Pax field type.
    defp atom_field_type(constraints) do
      if Keyword.get(constraints, :one_of), do: {:error, "TODO: Enums"}, else: {:ok, :string}
    end

    defp invalid_type(type, resource) do
      """
      Unknown Ash type #{inspect(type)} in resource #{inspect(resource)}.

      If you are using a custom type, you must create a custom Type module that implements the Pax.Field behaviour.
      """
    end

    @impl Pax.Adapter
    def singular_name(%{resource: resource}) do
      Pax.Util.Introspection.name_from_struct(resource)
    end

    @impl Pax.Adapter
    def plural_name(%{resource: resource}) do
      resource
      |> Pax.Util.Introspection.name_from_struct()
      |> Pax.Util.Inflection.pluralize()
    end

    @impl Pax.Adapter
    def id_fields(%{resource: resource}) do
      Ash.Resource.Info.primary_key(resource)
    end

    @impl Pax.Adapter
    def object_ids(_opts, _object), do: nil

    @impl Pax.Adapter
    def object_name(%{resource: resource}, object) do
      case Enum.find([:name, :title, :label], &Ash.Resource.Info.attribute(resource, &1)) do
        nil -> default_object_name(resource, object)
        field -> Map.get(object, field) || default_object_name(resource, object)
      end
    end

    defp default_object_name(resource, object) do
      name = Pax.Util.Introspection.name_from_struct(resource)

      case Ash.Resource.Info.primary_key(resource) do
        [primary_key] ->
          "#{name} #{Map.get(object, primary_key)}"

        primary_keys ->
          for primary_key <- primary_keys, reduce: name do
            name -> "#{name} #{primary_key}:#{Map.get(object, primary_key)}"
          end
      end
    end

    @impl Pax.Adapter
    def count_objects(opts, criteria, socket) do
      opts
      |> build_query(criteria)
      |> Ash.count!(call_opts(opts, socket))
    end

    @impl Pax.Adapter
    def list_objects(opts, criteria, socket) do
      opts
      |> build_query(criteria)
      |> sort(criteria)
      |> paginate(criteria)
      |> Ash.read!(call_opts(opts, socket))
    end

    defp build_query(%{resource: resource, read_action: read_action}, criteria) do
      query = if read_action, do: Ash.Query.for_read(resource, read_action), else: Ash.Query.new(resource)

      case Map.get(criteria, :filter) do
        nil -> query
        filter -> Ash.Query.do_filter(query, filter)
      end
    end

    defp sort(query, %{order_by: order_by}), do: Ash.Query.sort(query, ash_sort(order_by))
    defp sort(query, _criteria), do: query

    # Pax spells a null-ordered direction the way Ecto does, and Ash spells it `nils` rather than `nulls`. An
    # adapter that passes the word through raises inside Ash.Query.sort/2.
    defp ash_sort(order_by) when is_list(order_by), do: Enum.map(order_by, &ash_sort/1)
    defp ash_sort({direction, field}), do: {field, ash_direction(direction)}
    defp ash_sort(field), do: field

    defp ash_direction(:asc_nulls_first), do: :asc_nils_first
    defp ash_direction(:asc_nulls_last), do: :asc_nils_last
    defp ash_direction(:desc_nulls_first), do: :desc_nils_first
    defp ash_direction(:desc_nulls_last), do: :desc_nils_last
    defp ash_direction(direction), do: direction

    defp paginate(query, %{limit: limit, offset: offset}) do
      query |> Ash.Query.limit(limit) |> Ash.Query.offset(offset)
    end

    defp paginate(query, %{limit: limit}), do: Ash.Query.limit(query, limit)
    defp paginate(query, _criteria), do: query

    @impl Pax.Adapter
    def new_object(%{resource: resource}, _socket), do: struct(resource)

    @impl Pax.Adapter
    def get_object(opts, lookup, criteria, socket) do
      opts
      |> build_query(criteria)
      |> Ash.Query.do_filter(Map.to_list(lookup))
      |> Ash.read_one!(call_opts(opts, socket))
      |> case do
        nil -> raise Ash.Error.Query.NotFound.exception(resource: opts.resource)
        object -> object
      end
    end

    @impl Pax.Adapter
    def change_object(opts, object, socket) do
      form_opts =
        Keyword.merge(call_opts(opts, socket),
          as: to_string(Pax.Adapter.form_name()),
          domain: opts.domain
        )

      if new_object?(opts, object) do
        AshPhoenix.Form.for_create(opts.resource, create_action(opts), form_opts)
      else
        AshPhoenix.Form.for_update(object, update_action(opts), form_opts)
      end
    end

    # A new page's object is the bare struct from new_object/2, which has no primary key set yet.
    defp new_object?(%{resource: resource}, object) do
      Enum.all?(Ash.Resource.Info.primary_key(resource), &is_nil(Map.get(object, &1)))
    end

    defp create_action(%{resource: resource, create_action: nil}) do
      Ash.Resource.Info.primary_action!(resource, :create).name
    end

    defp create_action(%{create_action: create_action}), do: create_action

    defp update_action(%{resource: resource, update_action: nil}) do
      Ash.Resource.Info.primary_action!(resource, :update).name
    end

    defp update_action(%{update_action: update_action}), do: update_action

    @impl Pax.Adapter
    def validate_object(_opts, _object, form_data, params, _socket) do
      AshPhoenix.Form.validate(form_data, params)
    end

    @impl Pax.Adapter
    def create_object(_opts, _object, form_data, params, _socket) do
      AshPhoenix.Form.submit(form_data, params: params)
    end

    @impl Pax.Adapter
    def update_object(_opts, _object, form_data, params, _socket) do
      AshPhoenix.Form.submit(form_data, params: params)
    end

    # The actor and the tenant are resolved per call, never captured at init, so a host that re-reads the session
    # or lets an operator switch tenant is not stuck with a value frozen at mount.
    defp call_opts(opts, socket) do
      %{config: config} = socket.assigns.pax

      [
        actor: Pax.Config.get(config, [:adapter, :actor], [socket], nil),
        tenant: Pax.Config.get(config, [:adapter, :tenant], [socket], nil),
        domain: opts.domain
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    end
  end
end
