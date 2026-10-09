defmodule Pax.Field do
  @global_opts_schema NimbleOptions.new!(
                        label: [type: :string, doc: "The label, introspected from the field name by default."],
                        link: [
                          type: {:or, [{:in, [true]}, :string, {:struct, URI}, {:fun, 1}, {:tuple, [:atom, :atom]}]},
                          doc: """
                          Link the field. `true` links to the show path, or else the edit path. A string or `URI`
                          links there. A function, or a `{module, function}` tuple, is called with the object to get
                          the link.
                          """
                        ],
                        value: [
                          type: :any,
                          doc: """
                          The value to render, instead of the object's value for the field. Another field name, a
                          function of the object (or the field name and object), a `{module, function}` tuple, or a
                          static value. Fields with a value are immutable.
                          """
                        ],
                        immutable: [type: :boolean, doc: "Render the field as text, even in forms."],
                        required: [type: :boolean, doc: "Require the field in forms. Fields are required by default."],
                        only: [
                          type: {:or, [:atom, {:list, :atom}]},
                          doc: "The action, or list of actions, to include the field in."
                        ],
                        except: [
                          type: {:or, [:atom, {:list, :atom}]},
                          doc: "The action, or list of actions, to leave the field out of."
                        ],
                        sort: [
                          type: :atom,
                          doc:
                            "Make the field sortable. `true` sorts by the field itself, or give a field name to sort by."
                        ],
                        sort_asc: [
                          type: {:in, [:asc, :asc_nulls_first, :asc_nulls_last]},
                          doc: "The ascending direction to sort in. Defaults to `:asc`."
                        ],
                        sort_desc: [
                          type: {:in, [:desc, :desc_nulls_first, :desc_nulls_last]},
                          doc: "The descending direction to sort in. Defaults to `:desc`."
                        ]
                      )

  @global_opts Keyword.keys(@global_opts_schema.schema)

  @moduledoc """
  A field of the objects shown by a Pax.Interface. Fields are given as a list of fieldspecs, such as in the `:fields`
  config, in one of these forms:

    * `:name` - the type is introspected from the adapter.
    * `{:name, opts}` - the type is introspected from the adapter.
    * `{:name, :type}` or `{:name, :type, opts}` - `:type` is a built-in type: `:boolean`, `:date`, `:datetime`,
      `:float`, `:integer`, `:string` or `:time`.
    * `{:name, MyType}` or `{:name, MyType, opts}` - `MyType` implements `Pax.Field.Type`.

  ## Options

  Every field accepts these options. Each type also accepts its own, documented in the type's module, such as
  `Pax.Field.String`.

  #{NimbleOptions.docs(@global_opts_schema)}
  """

  alias Pax.Field

  defstruct name: nil, type: nil, opts: []

  @type t() :: %Field{
          name: atom(),
          type: atom() | module(),
          opts: map()
        }

  @type fieldspec() ::
          atom()
          | {atom(), atom() | module()}
          | {atom(), atom() | module(), keyword()}

  @doc false
  @spec init(Pax.Adapter.t(), fieldspec()) :: t()
  def init(nil, name) when is_atom(name) do
    raise_adapter_required_for_field_introspection(name)
  end

  def init(adapter, name) when is_atom(name) do
    type = Pax.Adapter.field_type!(adapter, name)
    do_init(name, type, [])
  end

  def init(nil, {name, opts}) when is_atom(name) and is_list(opts) do
    raise_adapter_required_for_field_introspection(name)
  end

  def init(adapter, {name, opts}) when is_atom(name) and is_list(opts) do
    type = Pax.Adapter.field_type!(adapter, name)
    do_init(name, type, opts)
  end

  def init(_adapter, {name, type}) when is_atom(name) and is_atom(type) do
    do_init(name, type, [])
  end

  def init(_adapter, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
    do_init(name, type, opts)
  end

  def init(_adapter, arg) do
    raise ArgumentError, """
    Invalid fieldspec #{inspect(arg)}. Must be one of:
      - `:name`
      - `{:name, :type}` where :type is a valid field type like `:string`, `:integer`, etc.
      - `{:name, MyType}` where MyType implements the Pax.Field.Type behaviour.
      - `{:name, :type, [opts]}` where :type is a valid field type like `:string`, `:integer`, etc.
      - `{:name, MyType, [opts]}` where MyType implements the Pax.Field.Type behaviour.
    """
  end

  defp raise_adapter_required_for_field_introspection(name) do
    raise """
    Unable to introspect field #{inspect(name)}.

    You must specify the field's type when not using a Pax.Adapter.

    Examples:
    - {:name, :string}
    - {:age, :integer, required: true}
    - {:is_active, :boolean, required: false}
    """
  end

  defp do_init(name, :boolean, opts) do
    do_init(name, Field.Boolean, opts)
  end

  defp do_init(name, :date, opts) do
    do_init(name, Field.Date, opts)
  end

  defp do_init(name, :datetime, opts) do
    do_init(name, Field.Datetime, opts)
  end

  defp do_init(name, :time, opts) do
    do_init(name, Field.Time, opts)
  end

  # TODO: :decimal

  defp do_init(name, :float, opts) do
    do_init(name, Field.Float, opts)
  end

  defp do_init(name, :integer, opts) do
    do_init(name, Field.Integer, opts)
  end

  # TODO: :list
  # TODO: :map ?

  defp do_init(name, :string, opts) do
    do_init(name, Field.String, opts)
  end

  defp do_init(name, type, opts) do
    if Code.ensure_loaded?(type) and function_exported?(type, :init, 1) do
      validate_field_name!(name)

      if not Keyword.keyword?(opts) do
        raise ArgumentError,
              "Invalid options for field #{inspect(name)}, expected a keyword list, got: #{inspect(opts)}"
      end

      # The options every field accepts are validated here. The rest are the type's own, and are passed to it as given.
      {global_opts, type_opts} = Keyword.split(opts, @global_opts)
      global = init_global_opts(global_opts, name)
      opts = type.init(type_opts)

      %Field{
        name: name,
        type: type,
        opts: Map.merge(opts, global)
      }
    else
      raise ArgumentError,
            "Invalid field type: #{inspect(type)}. Field types must implement the Pax.Field.Type behaviour, " <>
              "including init/1."
    end
  end

  defp validate_field_name!(name) when is_atom(name) do
    case to_string(name) do
      "." <> _ -> raise ArgumentError, "Field name cannot start with a period: #{inspect(name)}"
      "-" <> _ -> raise ArgumentError, "Field name cannot start with a hyphen: #{inspect(name)}"
      "_" <> _ -> raise ArgumentError, "Field name cannot start with an underscore: #{inspect(name)}"
      "~" <> _ -> raise ArgumentError, "Field name cannot start with a tilde: #{inspect(name)}"
      _ -> :ok
    end
  end

  defp init_global_opts(opts, name) do
    opts
    |> Pax.Options.validate!(@global_opts_schema, "field #{inspect(name)}")
    |> Map.new()
    |> resolve_sort_opt(name)
  end

  # `sort: true` sorts by the field itself, and `sort: false` is the same as not sorting
  defp resolve_sort_opt(opts, name) do
    case Map.get(opts, :sort) do
      nil -> opts
      true -> Map.put(opts, :sort, name)
      false -> Map.delete(opts, :sort)
      field -> Map.put(opts, :sort, field)
    end
  end

  def label(%Field{name: name, opts: opts}) do
    Map.get(opts, :label) || Pax.Util.Introspection.field_name_to_label(name)
  end

  def link(%Field{} = field, object, opts \\ []) do
    local_params = Keyword.get(opts, :local_params)
    params = Keyword.get(opts, :params)

    field
    |> resolve_link(object)
    |> maybe_add_local_params(local_params)
    |> maybe_add_params(params)
  end

  defp resolve_link(field, object) do
    case Map.get(field.opts, :link, nil) do
      nil -> nil
      {mod, fun} when is_atom(mod) and is_atom(fun) -> resolve_link_from_mod_fun(field, object, mod, fun)
      fun when is_function(fun) -> resolve_link_from_function(field, object, fun)
      %URI{} = link -> link
      link -> link
    end
  end

  # Add params to the given link, as long as it's not nil, and there are params to add
  defp maybe_add_params(nil, _), do: nil
  defp maybe_add_params(link, nil), do: link

  defp maybe_add_params(link, params) when is_binary(link) do
    Pax.Util.URI.with_params(link, params)
  end

  defp maybe_add_params(%URI{} = link, params) do
    Pax.Util.URI.with_params(link, params)
  end

  # Add params to the given link if the link has no host
  defp maybe_add_local_params(nil, _), do: nil
  defp maybe_add_local_params(link, nil), do: link

  defp maybe_add_local_params(%URI{} = link, local_params) do
    case link.host do
      nil -> maybe_add_params(link, local_params)
      _ -> link
    end
  end

  defp maybe_add_local_params(link, local_params) when is_binary(link) do
    link
    |> URI.parse()
    |> maybe_add_local_params(local_params)
  end

  defp resolve_link_from_mod_fun(field, object, mod, fun) do
    cond do
      function_exported?(mod, fun, 1) ->
        link = apply(mod, fun, [object])
        resolve_returned_link(field, link)

      true ->
        raise UndefinedFunctionError,
              "function #{mod}.#{fun}/1 is undefined or private for field #{inspect(field.name)}"
    end
  end

  defp resolve_link_from_function(field, object, fun) do
    case Function.info(fun, :arity) do
      {:arity, 1} ->
        link = fun.(object)
        resolve_returned_link(field, link)

      _ ->
        raise ArgumentError, "Invalid function arity: #{inspect(fun)} for field #{inspect(field.name)}. Must be a fn/1."
    end
  end

  defp resolve_returned_link(field, link) do
    case link do
      nil ->
        nil

      false ->
        nil

      link when is_atom(link) ->
        to_string(link)

      link when is_binary(link) ->
        link

      %URI{} = link ->
        link

      link ->
        raise """
        Invalid link returned from link/1 function for field #{inspect(field.name)}.

        #{inspect(link)}

        Must be a string, atom or URI.
        """
    end
  end

  def set_link(field, link_spec) do
    %{field | opts: Map.put(field.opts, :link, link_spec)}
  end

  def render(%Field{name: name, type: type, opts: opts}, object) do
    value = resolve_value(name, object, Map.get(opts, :value))

    case type.render(opts, value) do
      nil -> "•"
      # nil -> "∅"
      value -> value
    end
  end

  defp resolve_value(name, object, value) do
    case value do
      nil -> Map.get(object, name)
      {mod, fun} when is_atom(mod) and is_atom(fun) -> resolve_value_from_mod_fun(name, object, mod, fun)
      fun when is_function(fun) -> resolve_value_from_function(name, object, fun)
      value when is_atom(value) -> resolve_value_from_field_name(name, object, value)
      _ -> value
    end
  end

  defp resolve_value_from_mod_fun(name, object, mod, fun) do
    cond do
      function_exported?(mod, fun, 2) -> apply(mod, fun, [name, object])
      function_exported?(mod, fun, 1) -> apply(mod, fun, [object])
      true -> raise UndefinedFunctionError, "functions #{mod}.#{fun}/1 or #{mod}.#{fun}/2 are undefined or private"
    end
  end

  defp resolve_value_from_function(name, object, fun) do
    case Function.info(fun, :arity) do
      {:arity, 1} -> fun.(object)
      {:arity, 2} -> fun.(name, object)
      _ -> raise ArgumentError, "Invalid function arity: #{inspect(fun)}. Must be a fn/1 or fn/2."
    end
  end

  defp resolve_value_from_field_name(_name, object, value) do
    if Map.has_key?(object, value) do
      Map.get(object, value)
    else
      raise "Invalid value: #{inspect(value)}. Must be a field name."
    end
  end

  def immutable?(%Field{type: type, opts: opts}) do
    cond do
      Map.get(opts, :immutable, false) -> true
      Map.get(opts, :value, nil) != nil -> true
      Code.ensure_loaded?(type) and function_exported?(type, :immutable?, 1) -> type.immutable?(opts)
      true -> false
    end
  end

  def required?(%Field{opts: opts}) do
    # Fields are required by default unless `required: false` is set in opts
    Map.get(opts, :required, true)
  end

  def mutable_fields(fields) do
    Enum.reject(fields, &immutable?/1)
  end

  @doc """
  The names of the fields a form must require: the mutable fields that are not `required: false`.

  Pax owns which fields a form requires, because that is field metadata. Enforcing it is the data layer's job,
  so an adapter feeds this list to whatever its form type uses, such as `Ecto.Changeset.validate_required/2`.
  """
  def required_field_names(fields) do
    fields
    |> Enum.filter(fn field -> not immutable?(field) and required?(field) end)
    |> Enum.map(fn %Field{name: name} -> name end)
  end

  def label_for(%Field{name: name}, nil), do: name

  def label_for(%Field{name: name}, form) do
    case form[name] do
      %Phoenix.HTML.FormField{} = field -> field.id || field.name || name
      _ -> name
    end
  end

  def input(%Field{name: name, type: type, opts: opts} = field, form) do
    form_field = form[name]
    type.input(opts, field, form_field)
  end

  # TODO: allow the type to override errors, and maybe the field opts?
  def errors(%Field{name: name}, form) do
    form_field = form[name]

    if Phoenix.Component.used_input?(form_field) do
      for error <- form_field.errors do
        translate_error(error)
      end
    else
      []
    end
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # When using gettext, we typically pass the strings we want
    # to translate as a static argument:
    #
    #     # Translate the number of files with plural rules
    #     dngettext("errors", "1 file", "%{count} files", count)
    #
    # However the error messages in our forms and APIs are generated
    # dynamically, so we need to translate them by calling Gettext
    # with our gettext backend as first argument. Translations are
    # available in the errors.po file (as we use the "errors" domain).
    if count = opts[:count] do
      Gettext.dngettext(Pax.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(Pax.Gettext, "errors", msg, opts)
    end
  end
end
