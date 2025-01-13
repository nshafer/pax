defmodule Pax.Config do
  @moduledoc """
  `Pax.Config` is a module for defining configuration structs and functions for Pax. It has two main concerns:

  1. Ingest and validate configuration data, checking for common mistakes and typos.
  2. Resolve configuration values for code that is configurable, calling functions and checking return types.

  ## Ingesting and validation

  Configuration data supplied by a developer is validated against a specification of expected keys and their possible
  types. These types are just basic Elixir types, such as would be checked with a guard clause. This is not intended to
  be a complete type system, just enough to help the developer if they make a mistake.

  ## Supported Types

  Config type                 | Elixir type     | Example
  :-------------------------- | :-------------- | :--------------------------------------------------------------
  `nil`                       | `nil`           | `nil`
  `:atom`                     | `atom()`        | `:foo`
  `:string`                   | `binary()`      | `"foo"`
  `:boolean`                  | `boolean()`     | `true`, `false`
  `:integer`                  | `integer()`     | `42`
  `:float`                    | `float()`       | `42.0`
  `:tuple`                    | `tuple()`       | `{1, 2, 3}`
  `:list`                     | `list()`        | `[1, 2, 3]`
  `:map`                      | `map()`         | `%{foo: "bar"}`
  `:module`                   | `module()`      | `MyProject.Module`
  `:struct`                   | `struct()`      | `%MyStruct{name: "foo"}`
  `{:struct, Module}`         | `struct()`      | `{:struct, MyStruct}` => `%MyStruct{name: "foo"}`
  `:date`                     | `Date`          | `~D[2020-01-01]`
  `:time`                     | `Time`          | `~T[12:00:00]`
  `:naive_datetime`           | `NaiveDateTime` | `~N[2020-01-01 12:00:00]`
  `:datetime`                 | `DateTime`      | `~U[2020-01-01 12:00:00Z]`
  `:uri`                      | `URI`           | `URI.parse("https://example.com")`
  `:function`                 | `function()`    | `:function` => `fn -> "foo" end`
  `{:function, arity}`        | `function()`    | `{:function, 1}` => `fn x -> x end`
  `{:function, type}`         | `function()`    | `{function, :atom}` => `fn -> :foo end`
  `{:function, types}`        | `function()`    | `{function, [nil, :atom, :string]}` => `fn -> "foo" end`
  `{:function, arity, type}`  | `function()`    | `{:function, 2, :integer}` => `fn x, y -> x * y end`
  `{:function, arity, types}` | `function()`    | `{:function, 2, [:integer, nil]}` => `fn _, _ -> nil end`

  The spec of types can either be a single type, or a list of types. If a list of types is provided, the value must
  match at least one of the types in the list.

  Any extra keys in the config data that are not expected will return an error.

  A map of validated configuration is returned, with the same keys, pointing to a map of `%{value: value, type: type}`
  based on the detected type.

  ## Resolving configuration values

  Since configuration values can be functions, this module provides a way to call those functions and get the resolved
  value. This is useful for code that wants to use the configuration data without having to know how to call functions.
  If the spec allows a function, then when you get the value you must pass the args (if any) that would be required to
  resolve the function. The args are only used if the user supplied an anonymous function as the value for that config
  key.

  For example, if your spec is:

      spec =
        %{
          foo: [:integer, {:function, 1, :integer}]
        }

  Then when you fetch the config value for the `:foo` config key, you must pass the argument expected by the function,
  even if the user hasn't provided a function, and instead just provided an integer.

      # The user has provided an integer instead of a function returning an integer
      iex> {:ok, config} = Pax.Config.validate(spec, %{foo: 42}))

      # But when you fetch the value, you must pass the argument expected by the function
      iex> Pax.Config.fetch(config, :foo, [socket])
      42

      # This is so if the user provided a function, then fetching the value will be able
      # to pass that arg to the user-supplied function.
      iex> data = %{foo: fn socket -> if connected?(socket), do: 1, else: 0 end}
      iex> {:ok, config} = Pax.Config.validate(spec, data)
      iex> Pax.Config.fetch(config, :foo, [socket])
      0

  """

  # TODO: make the error messages much easier to read by dev that is unfamiliar with this module

  @validate_config_spec Application.compile_env(:pax, :validate_config_spec, false)

  @valid_spec_types ~w(
    nil
    atom string
    boolean
    integer float
    tuple list map
    module struct
    date time naive_datetime datetime uri
    function
  )a

  @doc """
  Validate user-provided configuration `data` against a configuration `spec`.

  The `spec` is a map of expected keys and the type (or types) that the data should provide. Please see
  [Supported Types](`m:Pax.Config#module-supported-types`) for the list of allowed types.

  If the `spec` has has any errors then a `Pax.Config.SpecError` will be raised.

  If the `data` does conform to the spec, then `{:ok, config}` will be returned, where `config` is a map using the same
  keys as the spec, but with a map of `%{value: value, type: type}` based on the detected type. This will be used by
  the `fetch/3` and `get/4` functions to resolve the function with the detected type.

  Only keys that are given in the data will be returned in the config. If the spec has a key that is not in the data,
  then it will not be in the config.

  ## Options

  - `:validate_config_spec` - Validate the spec itself. This is useful to turn on when developing an adapter or plugin,
    but should be turned off in production to avoid unnecessary checks. Defaults to `false` unless the application env
    `:validate_config_spec` is set to `true` in the `:pax` application at compile time. E.g. in "config/dev.exs":

        config :pax, validate_config_spec: true

    If it is changed, you will need to `mix deps.compile --force pax` to recompile pax with the new value.
  """
  @spec validate(spec :: map(), data :: map() | keyword(), opts :: keyword()) :: {:ok, map()} | {:error, term()}
  def validate(spec, data, opts \\ []) when is_map(spec) and (is_map(data) or is_list(data)) do
    {:ok, validate!(spec, data, opts)}
  rescue
    e in Pax.ConfigError -> {:error, Exception.message(e)}
  end

  @doc """
  Validate user-provided configuration `data` against a configuration `spec`, raising an error if the data does not
  conform.

  The `spec` is a map of expected keys and the type (or types) that the data should provide. Please see
  [Supported Types](`m:Pax.Config#module-supported-types`) for the list of allowed types.

  If the `data` does conform to the spec, then `config` will be returned, where `config` is a map using the same keys
  as the spec, but with a map of `%{value: value, type: type}` based on the detected type. This will be used by the
  `fetch/3` and `get/4` functions to resolve the function with the detected type.

  Only keys that are given in the data will be returned in the config. If the spec has a key that is not in the data,
  then it will not be in the config.

  a `Pax.ConfigError` will be raised if the provided data has any keys that don't exist in the spec, or they have an
  invalid type.
  """
  @spec validate!(spec :: map(), data :: map() | keyword(), opts :: keyword()) :: map()
  def validate!(spec, data, opts \\ [])

  def validate!(spec, data, opts) when is_map(spec) and is_map(data) do
    if Keyword.get(opts, :validate_config_spec, @validate_config_spec) do
      validate_spec!(spec)
    end

    for {key, value} <- data, into: %{} do
      case Map.fetch(spec, key) do
        {:ok, allowed_type_or_types} ->
          case validate_value_type(key, value, allowed_type_or_types) do
            {:ok, type} ->
              {key, %{value: value, type: type}}

            {:error, reason} ->
              raise Pax.ConfigError, reason
          end

        :error ->
          raise Pax.ConfigError, "invalid key #{inspect(key)} in config"
      end
    end
  end

  def validate!(spec, data, opts) when is_map(spec) and is_list(data) do
    validate!(spec, Map.new(data), opts)
  end

  # Validate that the spec is a map of keys (atoms) to either allowed types, or list of allowed types.
  defp validate_spec!(spec) do
    for {key, type} <- spec do
      validate_spec_key!(key)
      validate_spec_type!(type)
    end
  end

  defp validate_spec_key!(key) do
    unless is_atom(key) do
      raise Pax.Config.SpecError, "invalid key '#{inspect(key)}` in spec, must be an atom"
    end
  end

  defp validate_spec_arity!(arity) do
    unless is_integer(arity) and arity >= 0 do
      raise Pax.Config.SpecError, "invalid arity '#{inspect(arity)}` in spec for function"
    end
  end

  defp validate_spec_type!({:struct, module}) when is_atom(module) do
    unless Code.ensure_loaded?(module) do
      raise Pax.Config.SpecError, "invalid module '#{inspect(module)}` in spec for struct"
    end
  end

  defp validate_spec_type!({:function, arity}) when is_integer(arity) do
    validate_spec_arity!(arity)
  end

  defp validate_spec_type!({:function, type}) when is_atom(type) do
    validate_spec_type!(type)
  end

  defp validate_spec_type!({:function, types}) when is_list(types) do
    Enum.each(types, fn type -> validate_spec_type!(type) end)
  end

  defp validate_spec_type!({:function, arity, type}) when is_integer(arity) and is_atom(type) do
    validate_spec_arity!(arity)
    validate_spec_type!(type)
  end

  defp validate_spec_type!({:function, arity, types}) when is_integer(arity) and is_list(types) do
    validate_spec_arity!(arity)
    Enum.each(types, fn type -> validate_spec_type!(type) end)
  end

  defp validate_spec_type!(type) when is_atom(type) do
    unless type in @valid_spec_types do
      raise Pax.Config.SpecError, "invalid type '#{inspect(type)}` in spec"
    end
  end

  defp validate_spec_type!(types) when is_list(types) do
    Enum.each(types, fn type -> validate_spec_type!(type) end)
  end

  defp validate_spec_type!(type) do
    raise Pax.Config.SpecError, "invalid type '#{inspect(type)}` in spec"
  end

  # validate the given value against a list of allowed types, returning the first type to match
  defp validate_value_type(key, value, allowed_types) when is_list(allowed_types) do
    case Enum.find(allowed_types, :nomatch, &type_match?(value, &1)) do
      :nomatch ->
        {:error,
         "invalid value for key #{inspect(key)}, must be one of #{inspect(allowed_types)} but got '#{inspect(value)}'"}

      type ->
        {:ok, type}
    end
  end

  # validate the given value against a single allowed type
  defp validate_value_type(key, value, allowed_type) do
    if type_match?(value, allowed_type) do
      {:ok, allowed_type}
    else
      {:error, "invalid value for key #{inspect(key)}, must be #{inspect(allowed_type)} but got '#{inspect(value)}'"}
    end
  end

  defp type_match?(value, nil), do: value == nil
  defp type_match?(value, :atom), do: is_atom(value)
  defp type_match?(value, :string), do: is_binary(value)
  defp type_match?(value, :boolean), do: is_boolean(value)
  defp type_match?(value, :integer), do: is_integer(value)
  defp type_match?(value, :float), do: is_float(value)
  defp type_match?(value, :tuple), do: is_tuple(value)
  defp type_match?(value, :list), do: is_list(value)
  defp type_match?(value, :map), do: is_map(value)
  defp type_match?(value, :module), do: is_atom(value) and Code.ensure_loaded?(value)
  defp type_match?(value, :struct), do: is_struct(value)
  defp type_match?(value, {:struct, module}), do: is_struct(value, module)
  defp type_match?(%Date{}, :date), do: true
  defp type_match?(%Time{}, :time), do: true
  defp type_match?(%NaiveDateTime{}, :naive_datetime), do: true
  defp type_match?(%DateTime{}, :datetime), do: true
  defp type_match?(%URI{}, :uri), do: true
  defp type_match?(value, :function), do: is_valid_function(value, 0)
  defp type_match?(value, {:function, arity_or_type}), do: is_valid_function(value, arity_or_type)
  defp type_match?(value, {:function, arity, type_or_types}), do: is_valid_function(value, arity, type_or_types)
  defp type_match?(_value, _type), do: false

  # If the spec doesn't care about arity, then just make sure it's a function
  defp is_valid_function(value, 0), do: is_function(value)

  # Make sure the value is a function of the correct arity
  defp is_valid_function(value, arity) when is_function(value) and is_integer(arity) do
    case Function.info(value, :arity) do
      {:arity, ^arity} -> true
      _ -> false
    end
  end

  # We can't validate that the given function is going to return the proper type until we call it, so just make sure
  # it's a function. We'll check the return type later when the value is fetched.
  defp is_valid_function(value, _type_or_types) when is_function(value), do: true

  # The value must not be a valid function
  defp is_valid_function(_, _), do: false

  # We can't validate the function's return type until we call it, so just make sure it's a function and the proper
  # arity
  defp is_valid_function(value, arity, type_or_types) when is_function(value) and is_integer(arity) do
    case Function.info(value, :arity) do
      {:arity, ^arity} -> is_valid_function(value, type_or_types)
      _ -> false
    end
  end

  # The value must not be a valid function
  defp is_valid_function(_, _, _), do: false

  @doc """
  Fetch a value for a specific `key` from a `config` map.

  The `config` map must be the result of a call to `validate/3`.

  In the case that a function is allowed in the spec, then the correct args must be passed to this function to resolve
  the value. If no functions are allowed by the spec, the args can be omitted.

  An `ArgumentError` will be raised if the config is not a map with the correct structure, as returned from
  `validate/3`.

  A `Pax.Config.TypeError` will be raised if the function provided by the user does not return the correct type, as
  specified by the spec.

  A `Pax.Config.ArityError` will be raised if the count of args given to this function do not match one of the specs
  for the given key.
  """
  @spec fetch(config :: map(), key :: atom, args :: list()) :: {:ok, any()} | :error
  def fetch(config, key, args \\ []) when is_map(config) do
    {:ok, fetch!(config, key, args)}
  rescue
    KeyError -> :error
  end

  @doc """
  Fetch a value for a specific `key` from a `config` map, raising an error if the key is not found.

  The `config` map must be the result of a call to `validate/3`.

  In the case that a function is allowed in the spec, then the correct args must be passed to this function to resolve
  the value. If no functions are allowed by the spec, the args can be omitted.

  A `KeyError` will be raised if the key is not found in the configuration, which means it was not in the data given to
  `validate/3`.

  An `ArgumentError` will be raised if the config is not a map with the correct structure, as returned from
  `validate/3`.

  A `Pax.Config.TypeError` will be raised if the function provided by the user does not return the correct type, as
  specified by the spec.

  A `Pax.Config.ArityError` will be raised if the count of args given to this function do not match one of the specs
  for the given key.
  """
  @spec fetch!(config :: map(), key :: atom, args :: list()) :: any()
  def fetch!(config, key, args \\ []) when is_map(config) do
    case Map.fetch!(config, key) do
      %{value: value, type: :function} ->
        value.()

      %{value: value, type: {:function, arity}} when is_integer(arity) ->
        if length(args) == arity do
          apply(value, args)
        else
          raise Pax.Config.ArityError, "function for #{inspect(key)} requires #{arity} args, but got #{length(args)}"
        end

      %{value: value, type: {:function, return_type}} when is_atom(return_type) or is_list(return_type) ->
        value
        |> apply(args)
        |> check_return(return_type)

      %{value: value, type: {:function, arity, return_type_or_types}}
      when is_integer(arity) and (is_atom(return_type_or_types) or is_list(return_type_or_types)) ->
        if length(args) == arity do
          value
          |> apply(args)
          |> check_return(return_type_or_types)
        else
          raise Pax.Config.ArityError, "function for #{inspect(key)} requires #{arity} args, but got #{length(args)}"
        end

      %{value: value, type: type} ->
        check_return(value, type)

      _ ->
        raise ArgumentError, "invalid config data for key '#{inspect(key)}', should be a map with :value and :type"
    end
  end

  @doc """
  Gets the value for a specific `key` from a `config` map, returning the `default` if not found.

  The `config` map must be the result of a call to `validate/3`.

  In the case that a function is allowed in the spec, then the correct `args` must be passed to this function to
  resolve the value. If no functions are allowed by the spec, the `args` can be omitted.

  > #### Important Note {: .error}
  > If you are passing a `default` that is a list, then you need to use the `get/4` function with an empty list
  > for the `args`, otherwise the `default` will be treated as the `args`, and the `default` will actually be `nil`
  >
  >     iex> Pax.Config.get(config, :key, [], [1, 2, 3])

  An `ArgumentError` will be raised if the config is not a map with the correct structure, as returned from
  `validate/3`.

  A `Pax.Config.TypeError` will be raised if the function provided by the user does not return the correct type, as
  specified by the spec.

  A `Pax.Config.ArityError` will be raised if the count of args given to this function do not match one of the specs
  for the given key.
  """
  def get(config, key, args \\ [], default \\ nil)

  def get(config, key, args, default) when is_map(config) and is_list(args) do
    case fetch(config, key, args) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get(config, key, default, nil) when is_map(config) do
    get(config, key, [], default)
  end

  defp check_return(value, types) when is_list(types) do
    if Enum.any?(types, &type_match?(value, &1)) do
      value
    else
      raise Pax.Config.TypeError, "invalid type for value '#{inspect(value)}', should be one of #{inspect(types)}"
    end
  end

  defp check_return(value, type) do
    if type_match?(value, type) do
      value
    else
      raise Pax.Config.TypeError, "invalid type for value '#{inspect(value)}', should be #{inspect(type)}"
    end
  end
end
