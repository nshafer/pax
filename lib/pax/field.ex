defmodule Pax.Field do
  @type field() ::
          atom()
          | {atom(), atom() | module()}
          | {atom(), atom() | module(), keyword()}

  @callback init(live_module :: module(), opts :: []) :: map()
  @callback render(opts :: any(), value :: any()) :: String.t() | nil

  alias Pax.Field
  require Logger

  @global_opts [:title, :link, :value]

  def init(mod, adapter, name) when is_atom(name) do
    type = Pax.Adapter.field_type(adapter, name)
    init(mod, adapter, name, type, [])
  end

  def init(mod, adapter, {name, opts}) when is_atom(name) and is_list(opts) do
    type = Pax.Adapter.field_type(adapter, name)
    init(mod, adapter, name, type, opts)
  end

  def init(mod, adapter, {name, type}) when is_atom(name) and is_atom(type) do
    init(mod, adapter, name, type, [])
  end

  def init(mod, adapter, {name, type, opts}) when is_atom(name) and is_atom(type) and is_list(opts) do
    init(mod, adapter, name, type, opts)
  end

  def init(_mod, _adapter, arg) do
    raise ArgumentError, """
    Invalid field #{inspect(arg)}. Must be {:name, :type, [opts]} or {:name, MyType, [opts]} where MyType
    implements the Pax.Field behaviour.
    """
  end

  def init(mod, adapter, name, :boolean, opts) do
    init(mod, adapter, name, Field.Boolean, opts)
  end

  def init(mod, adapter, name, :date, opts) do
    init(mod, adapter, name, Field.Date, opts)
  end

  def init(mod, adapter, name, :datetime, opts) do
    init(mod, adapter, name, Field.Datetime, opts)
  end

  def init(mod, adapter, name, :time, opts) do
    init(mod, adapter, name, Field.Time, opts)
  end

  # TODO: :decimal

  def init(mod, adapter, name, :float, opts) do
    init(mod, adapter, name, Field.Float, opts)
  end

  def init(mod, adapter, name, :integer, opts) do
    init(mod, adapter, name, Field.Integer, opts)
  end

  # TODO: :list
  # TODO: :map ?

  def init(mod, adapter, name, :string, opts) do
    init(mod, adapter, name, Field.String, opts)
  end

  def init(mod, _adapter, name, type, opts) do
    if Code.ensure_loaded?(type) and function_exported?(type, :init, 2) do
      global = init_global_opts(opts, mod)
      opts = type.init(mod, opts)
      {name, type, Map.merge(opts, global)}
    else
      raise ArgumentError, "Invalid field type: #{inspect(type)}."
    end
  end

  defp init_global_opts(opts, mod) do
    Keyword.take(opts, @global_opts)
    |> Map.new()
    |> resolve_link_opt(mod)
  end

  defp resolve_link_opt(opts, mod) do
    case Map.get(opts, :link) do
      nil ->
        opts

      true ->
        cond do
          function_exported?(mod, :link, 2) -> Map.put(opts, :link, {mod, :link})
          function_exported?(mod, :link, 1) -> Map.put(opts, :link, {mod, :link})
          true -> raise "You must implement a link/1 or link/2 function in #{inspect(mod)} to set link: true"
        end

      {mod, fun} when is_atom(mod) and is_atom(fun) ->
        opts

      fun when is_function(fun) ->
        opts

      link when is_atom(link) or is_binary(link) ->
        opts

      %URI{} ->
        opts

      _ ->
        raise "Invalid link option: #{inspect(opts[:link])}"
    end
  end

  def title({name, _type, opts}) do
    case Map.get(opts, :title) do
      nil -> name_to_title(name)
      title -> title
    end
  end

  defp name_to_title(name) do
    name
    |> Atom.to_string()
    |> String.slice(0..100)
    |> String.split(~r/[\W_]/)
    |> Enum.take(5)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> String.slice(0..25)
  end

  def link({_name, _type, opts}, object, fun_opts \\ []) do
    resolve_link(object, Map.get(opts, :link), fun_opts)
  end

  defp resolve_link(object, link_opt, fun_opts) do
    case link_opt do
      nil -> nil
      {mod, fun} when is_atom(mod) and is_atom(fun) -> resolve_link_from_mod_fun(object, mod, fun, fun_opts)
      fun when is_function(fun) -> resolve_link_from_function(object, fun, fun_opts)
      %URI{} = link -> URI.to_string(link)
      _ -> link_opt
    end
  end

  defp resolve_link_from_mod_fun(object, mod, fun, fun_opts) do
    cond do
      function_exported?(mod, fun, 2) -> apply(mod, fun, [object, fun_opts]) |> resolve_returned_link()
      function_exported?(mod, fun, 1) -> apply(mod, fun, [object]) |> resolve_returned_link()
      true -> raise UndefinedFunctionError, "functions #{mod}.#{fun}/1 or #{mod}.#{fun}/1 are undefined or private"
    end
  end

  defp resolve_link_from_function(object, fun, fun_opts) do
    case Function.info(fun, :arity) do
      {:arity, 2} -> fun.(object, fun_opts) |> resolve_returned_link()
      {:arity, 1} -> fun.(object) |> resolve_returned_link()
      _ -> raise ArgumentError, "Invalid function arity: #{inspect(fun)}. Must be a fn/1 or fn/2."
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

  def render({name, type, opts}, object) do
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
end
