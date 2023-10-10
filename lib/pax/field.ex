defmodule Pax.Field do
  alias Pax.Field
  require Logger

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

  @global_opts [:label, :link, :value, :immutable, :required]

  @doc false
  @spec init(Pax.Adapter.t(), fieldspec()) :: t()
  def init(adapter, name) when is_atom(name) do
    type = Pax.Adapter.field_type!(adapter, name)
    do_init(adapter, name, type, [])
  end

  def init(adapter, {name, opts}) when is_atom(name) and is_list(opts) do
    type = Pax.Adapter.field_type!(adapter, name)
    do_init(adapter, name, type, opts)
  end

  def init(adapter, {name, type}) when is_atom(name) and is_atom(type) do
    do_init(adapter, name, type, [])
  end

  def init(adapter, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
    do_init(adapter, name, type, opts)
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

  defp do_init(adapter, name, :boolean, opts) do
    do_init(adapter, name, Field.Boolean, opts)
  end

  defp do_init(adapter, name, :date, opts) do
    do_init(adapter, name, Field.Date, opts)
  end

  defp do_init(adapter, name, :datetime, opts) do
    do_init(adapter, name, Field.Datetime, opts)
  end

  defp do_init(adapter, name, :time, opts) do
    do_init(adapter, name, Field.Time, opts)
  end

  # TODO: :decimal

  defp do_init(adapter, name, :float, opts) do
    do_init(adapter, name, Field.Float, opts)
  end

  defp do_init(adapter, name, :integer, opts) do
    do_init(adapter, name, Field.Integer, opts)
  end

  # TODO: :list
  # TODO: :map ?

  defp do_init(adapter, name, :string, opts) do
    do_init(adapter, name, Field.String, opts)
  end

  defp do_init(_adapter, name, type, opts) do
    if Code.ensure_loaded?(type) and function_exported?(type, :init, 1) do
      global = init_global_opts(opts)
      opts = type.init(opts)

      %Field{
        name: name,
        type: type,
        opts: Map.merge(opts, global)
      }
    else
      raise ArgumentError, "Invalid field type: #{inspect(type)}."
    end
  end

  defp init_global_opts(opts) do
    Keyword.take(opts, @global_opts)
    |> Map.new()
    |> resolve_link_opt()
  end

  defp resolve_link_opt(opts) do
    case Map.get(opts, :link) do
      nil -> opts
      {mod, fun} when is_atom(mod) and is_atom(fun) -> opts
      fun when is_function(fun) -> opts
      link when is_atom(link) or is_binary(link) -> opts
      %URI{} -> opts
      _ -> raise "Invalid link option: #{inspect(opts[:link])}"
    end
  end

  def label(%Field{name: name, opts: opts}) do
    Map.get(opts, :label) || Pax.Util.Introspection.field_name_to_label(name)
  end

  def link(%Field{opts: opts}, object) do
    case Map.get(opts, :link, nil) do
      nil -> nil
      {mod, fun} when is_atom(mod) and is_atom(fun) -> resolve_link_from_mod_fun(object, mod, fun)
      fun when is_function(fun) -> resolve_link_from_function(object, fun)
      %URI{} = link -> URI.to_string(link)
      link -> link
    end
  end

  defp resolve_link_from_mod_fun(object, mod, fun) do
    cond do
      function_exported?(mod, fun, 1) -> apply(mod, fun, [object]) |> resolve_returned_link()
      true -> raise UndefinedFunctionError, "function #{mod}.#{fun}/1 is undefined or private"
    end
  end

  defp resolve_link_from_function(object, fun) do
    case Function.info(fun, :arity) do
      {:arity, 1} -> fun.(object) |> resolve_returned_link()
      _ -> raise ArgumentError, "Invalid function arity: #{inspect(fun)}. Must be a fn/1."
    end
  end

  defp resolve_returned_link(link) do
    case link do
      nil ->
        nil

      false ->
        nil

      link when is_atom(link) ->
        to_string(link)

      link when is_binary(link) ->
        link

      %URI{} ->
        URI.to_string(link)

      _ ->
        Logger.warning(
          "Invalid link returned from link/1 function. Must be a string, atom or URI. Got: #{inspect(link)}"
        )

        nil
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

  def label_for(%Field{name: name}, nil), do: name

  def label_for(%Field{name: name}, form) do
    case form[name] do
      %Phoenix.HTML.FormField{} = field -> field.id || field.name || name
      _ -> name
    end
  end

  def feedback_for(%Field{name: name}, nil), do: name

  def feedback_for(%Field{name: name}, form) do
    case form[name] do
      %Phoenix.HTML.FormField{} = field -> field.name || name
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

    for error <- form_field.errors do
      translate_error(error)
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
