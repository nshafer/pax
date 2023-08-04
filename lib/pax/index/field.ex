defmodule Pax.Index.Field do
  @callback init(live_module :: module(), opts :: []) :: map()
  @callback render(opts :: any(), value :: any()) :: String.t()

  alias Pax.Index.Field

  @global_opts [:title, :link, :value]

  def init(mod, :boolean, opts) do
    init(mod, Field.Boolean, opts)
  end

  def init(mod, :date, opts) do
    init(mod, Field.Date, opts)
  end

  def init(mod, :datetime, opts) do
    init(mod, Field.Datetime, opts)
  end

  def init(mod, :time, opts) do
    init(mod, Field.Time, opts)
  end

  # TODO: :decimal

  def init(mod, :float, opts) do
    init(mod, Field.Float, opts)
  end

  def init(mod, :integer, opts) do
    init(mod, Field.Integer, opts)
  end

  # TODO: :list
  # TODO: :map ?

  def init(mod, :string, opts) do
    init(mod, Field.String, opts)
  end

  def init(mod, type, opts) do
    if function_exported?(type, :init, 2) do
      global = Keyword.take(opts, @global_opts) |> Map.new()
      opts = type.init(mod, opts)
      {type, Map.merge(opts, global)}
    else
      raise ArgumentError, "Invalid field type: #{inspect(type)}."
    end
  end

  def title(_mod, {name, _type, opts}) do
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

  def render(mod, {name, type, opts}, object) do
    value = resolve_value(mod, name, object, Map.get(opts, :value))
    type.render(opts, value)
  end

  defp resolve_value(mod, name, object, value) do
    case value do
      nil -> Map.get(object, name)
      {mod, fun} when is_atom(mod) and is_atom(fun) -> resolve_value_from_mod_fun(mod, fun, name, object)
      value when is_atom(value) -> resolve_value_from_function_or_field(mod, name, object, value)
      _ -> value
    end
  end

  defp resolve_value_from_mod_fun(mod, fun, name, object) do
    cond do
      function_exported?(mod, fun, 2) -> apply(mod, fun, [name, object])
      function_exported?(mod, fun, 1) -> apply(mod, fun, [object])
      true -> raise UndefinedFunctionError, "functions #{mod}.#{fun}/1 or #{mod}.#{fun}/2 are undefined or private"
    end
  end

  defp resolve_value_from_function_or_field(mod, name, object, value) do
    cond do
      value = resolve_value_from_function(mod, name, object, value) ->
        value

      value = resolve_value_from_field(mod, object, value) ->
        value

      true ->
        raise "Invalid value: #{inspect(value)} for field #{inspect(name)}. Must be a function/1, function/2 or a field."
    end
  end

  defp resolve_value_from_function(mod, name, object, value) do
    cond do
      function_exported?(mod, value, 2) -> apply(mod, value, [name, object])
      function_exported?(mod, value, 1) -> apply(mod, value, [object])
      true -> nil
    end
  end

  defp resolve_value_from_field(_mod, object, value) do
    if Map.has_key?(object, value) do
      Map.get(object, value)
    else
      nil
    end
  end
end
