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

  A map of validated configuration is returned that can be used with `fetch/3`, `fetch!/3` and `get/4` to resolve the
  configuration values.

  ## Nested Configuration

  The spec can be a map of keys to either types, or another map of keys to types. This allows for nested configuration
  data.

  For example, you can have a spec like the following, then the data must conform to the spec with the same nesting.

      iex> spec = %{
      ...>   foo: [:integer, {:function, 1, :integer}],
      ...>   bar: %{
      ...>     baz: [:string]
      ...>   }
      ...> }
      ...> data = [
      ...>   foo: 42,
      ...>   bar: [
      ...>     baz: "hello"
      ...>   ]
      ...> ]
      ...> {:ok, _config} = Pax.Config.validate(spec, data)
      {:ok,
        %{
          foo: {:integer, 42},
          bar: %{baz: {:string, "hello"}}
        }}

  To fetch the configured value of nested keys, you can use the `fetch/3`, `fetch!/3` and `get/4` functions with a
  list of keys, similar to the `get_in/2` function in Elixir.

      iex> spec = %{foo: [:integer, {:function, 1, :integer}], bar: %{:baz => [:string]}}
      ...> data = [foo: 42, bar: [baz: "hello"]]
      ...> config = Pax.Config.validate!(spec, data)
      ...> Pax.Config.fetch(config, :foo)
      {:ok, 42}
      ...> Pax.Config.get(config, [:bar, :baz])
      "hello"

  ## Resolving configuration values

  Since configuration values can be functions, this module provides a way to call those functions and get the resolved
  value. This is useful for code that wants to use the configuration data without having to know how to call functions.
  If the spec allows a function, then when you get the value you must pass the args (if any) that would be required to
  resolve the function. The args are only used if the user supplied an anonymous function as the value for that config
  key.

  For example, if your spec is like the following, then when you fetch the config value for the `:foo` config key, you
  must pass the argument expected by the function, even if the user hasn't provided a function, and instead just
  provided a value.

      iex> spec = %{
      ...>   foo: [:integer, {:function, 1, :integer}]
      ...> }
      ...>
      ...> # The user has provided an integer instead of a function returning an integer, but when
      ...> # fetching the value, you still must pass the argument expected by the function
      ...> data = %{foo: 42}
      ...> config = Pax.Config.validate!(spec, data)
      ...> Pax.Config.fetch(config, :foo, [:arg])
      {:ok, 42}
      ...>
      ...> # This is so if the user provided a function, then fetching the value will be able
      ...> # to pass that arg to the user-supplied function.
      ...> data = %{foo: fn arg -> if arg == :one, do: 1, else: 0 end}
      ...> {:ok, config} = Pax.Config.validate(spec, data)
      ...> Pax.Config.fetch(config, :foo, [:one])
      {:ok, 1}

  """

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

  If the `data` does conform to the spec, then `{:ok, config}` will be returned, where `config` is a map of
  validated configuration that can be used with the `fetch/3`, `fetch!/3` and `get/4` functions to resolve the value.

  If the data not not conform to the spec, then `{:error, reason}` will be returned, where `reason` is a string
  describing the error.

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

  If the `data` does conform to the spec, then `{:ok, config}` will be returned, where `config` is a map of
  validated configuration that can be used with the `fetch/3`, `fetch!/3` and `get/4` functions to resolve the value.

  Only keys that are given in the data will be returned in the config. If the spec has a key that is not in the data,
  then it will not be in the config.

  If the data does not form to the spec, then a `Pax.ConfigError` will be raised.

  ## Options

  - `:validate_config_spec` - Validate the spec itself, raising a `Pax.Config.SpecError` in the case of errors.
    This is useful to turn on when developing an adapter or plugin, but should be turned off in production to avoid
    unnecessary checks. Defaults to `false` unless the application env `:validate_config_spec` is set to `true` in the
    `:pax` application at compile time. E.g. in "config/dev.exs":

        config :pax, validate_config_spec: true

    If it is changed, you will need to `mix deps.compile --force pax` to recompile pax with the new value.
  """
  @spec validate!(spec :: map(), data :: map() | keyword(), opts :: keyword()) :: map()
  def validate!(spec, data, opts \\ [])

  def validate!(spec, data, opts) when is_map(spec) and is_map(data) do
    if Keyword.get(opts, :validate_config_spec, @validate_config_spec) do
      validate_spec!(spec)
    end

    do_validate!(spec, data, [], opts)
  end

  def validate!(spec, data, opts) when is_map(spec) and is_list(data) do
    validate!(spec, Map.new(data), opts)
  end

  defp do_validate!(%{} = spec, %{} = data, stack, opts) do
    for {key, value} <- data, into: %{} do
      case Map.fetch(spec, key) do
        {:ok, %{} = sub_spec} ->
          case value do
            value when is_map(value) ->
              {key, do_validate!(sub_spec, value, [key | stack], opts)}

            value when is_list(value) ->
              {key, do_validate!(sub_spec, Map.new(value), [key | stack], opts)}

            value ->
              raise Pax.ConfigError,
                    "invalid value for key #{key_path(stack, key)}, " <>
                      "must be a map or a keyword list, but got #{inspect(value)}"
          end

        {:ok, allowed_type_or_types} ->
          {key, {validate_value_type!(key, value, allowed_type_or_types), value}}

        :error ->
          raise Pax.ConfigError, "invalid key #{key_path(stack, key)} in config"
      end
    end
  end

  defp key_path(stack, key) do
    path =
      [key | stack]
      |> Enum.map(&inspect/1)
      |> Enum.reverse()

    Enum.join(path, "/")
  end

  # Validate that the spec is a map of keys (atoms) to either allowed types, or list of allowed types.
  defp validate_spec!(spec) do
    for {key, type} <- spec do
      case {key, type} do
        {key, %{} = sub_spec} ->
          validate_spec_key!(key)
          validate_spec!(sub_spec)

        {key, type} ->
          validate_spec_key!(key)
          validate_spec_type!(type)
      end
    end
  end

  defp validate_spec_key!(key) do
    unless is_atom(key) do
      raise Pax.Config.SpecError, "invalid key '#{inspect(key)}` in spec, must be an atom"
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

  defp validate_spec_arity!(arity) do
    unless is_integer(arity) and arity >= 0 do
      raise Pax.Config.SpecError, "invalid arity '#{inspect(arity)}` in spec for function"
    end
  end

  # validate the given value against a list of allowed types, returning the first type to match
  defp validate_value_type!(key, value, allowed_types) when is_list(allowed_types) do
    case Enum.find(allowed_types, :no_match, &type_match?(value, &1)) do
      :no_match -> raise Pax.Config.TypeError, key: key, value: value, types: allowed_types
      type -> type
    end
  end

  # validate the given value against a single allowed type
  defp validate_value_type!(key, value, allowed_type) do
    if type_match?(value, allowed_type) do
      allowed_type
    else
      raise Pax.Config.TypeError, key: key, value: value, type: allowed_type
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
  Fetch a value for a specific `key` from a `config` map. Returns `{:ok, value}` if the key is found in the config,
  otherwise `:error`.

  The `config` map must be the result of a call to `validate/3`.

  Either an individual `key` can be given, or a list of `keys` if the configuration data is nested. See
  [Nested Configuration](`m:Pax.Config#module-nested-configuration`) for more information.

  In the case that a function is allowed in the spec, then the correct `args` must be passed to this function to
  resolve the value. If no functions are allowed by the spec, the args can be omitted.

  An `ArgumentError` will be raised if the config is not a map with the correct structure, as returned from
  `validate/3`.

  A `Pax.Config.TypeError` will be raised if the function provided by the user does not return the correct type, as
  specified by the spec.

  A `Pax.Config.ArityError` will be raised if the count of args given to this function do not match one of the specs
  for the given key.
  """
  @spec fetch(config :: map(), key_or_keys :: atom, args :: list()) :: {:ok, any()} | :error
  def fetch(config, key_or_keys, args \\ [])

  def fetch(config, [key], args) when is_map(config) do
    fetch(config, key, args)
  end

  def fetch(config, [key | rest], args) when is_map(config) do
    case Map.fetch(config, key) do
      {:ok, value} ->
        fetch(value, rest, args)

      :error ->
        :error
    end
  end

  def fetch(config, key, args) when is_map(config) do
    case Map.fetch(config, key) do
      {:ok, {:function, value}} ->
        {:ok, value.()}

      {:ok, {{:function, arity}, value}} when is_integer(arity) ->
        if length(args) == arity do
          {:ok, apply(value, args)}
        else
          raise Pax.Config.ArityError, "function for #{inspect(key)} requires #{arity} args, but got #{length(args)}"
        end

      {:ok, {{:function, return_type}, value}} when is_atom(return_type) or is_list(return_type) ->
        {:ok,
         value
         |> apply(args)
         |> check_value_type!(return_type, key, true)}

      {:ok, {{:function, arity, return_type_or_types}, value}}
      when is_integer(arity) and (is_atom(return_type_or_types) or is_list(return_type_or_types)) ->
        if length(args) == arity do
          {:ok,
           value
           |> apply(args)
           |> check_value_type!(return_type_or_types, key, true)}
        else
          raise Pax.Config.ArityError, "function for #{inspect(key)} requires #{arity} args, but got #{length(args)}"
        end

      {:ok, {type, value}} ->
        {:ok, check_value_type!(value, type, key)}

      {:ok, _} ->
        raise ArgumentError, "invalid config data for key '#{inspect(key)}', should be a 2-tuple of {type, value}"

      :error ->
        :error
    end
  end

  @doc """
  Fetch a value for a specific `key` from a `config` map, raising an error if the key is not found.

  The `config` map must be the result of a call to `validate/3`.

  Either an individual `key` can be given, or a list of `keys` if the configuration data is nested. See
  [Nested Configuration](`m:Pax.Config#module-nested-configuration`) for more information.

  In the case that a function is allowed in the spec, then the correct `args` must be passed to this function to resolve
  the value. If no functions are allowed by the spec, the args can be omitted.

  A `KeyError` will be raised if the key is not found in the configuration, which means it was not in the
  data given to `validate/3`.

  An `ArgumentError` will be raised if the config is not a map with the correct structure, as returned from
  `validate/3`.

  A `Pax.Config.TypeError` will be raised if the function provided by the user does not return the correct type, as
  specified by the spec.

  A `Pax.Config.ArityError` will be raised if the count of args given to this function do not match one of the specs
  for the given key.
  """
  @spec fetch!(config :: map(), key_or_keys :: atom | nonempty_list(atom), args :: list()) :: any()
  def fetch!(config, key, args \\ []) when is_atom(key) and is_map(config) do
    case fetch(config, key, args) do
      {:ok, value} -> value
      :error -> raise KeyError, term: config, key: key
    end
  end

  @doc """
  Gets the value for a specific `key` from a `config` map, returning the `default` if not found.

  The `config` map must be the result of a call to `validate/3`.

  Either an individual `key` can be given, or a list of `keys` if the configuration data is nested. See
  [Nested Configuration](`m:Pax.Config#module-nested-configuration`) for more information.

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
  @spec get(config :: map(), key_or_keys :: atom | nonempty_list(atom), args :: list(), default :: any()) :: any()
  def get(config, key_or_keys, args \\ [], default \\ nil)

  def get(config, key_or_keys, args, default)
      when (is_list(key_or_keys) or is_atom(key_or_keys)) and is_map(config) and is_list(args) do
    case fetch(config, key_or_keys, args) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def get(config, key_or_keys, default, nil) when (is_list(key_or_keys) or is_atom(key_or_keys)) and is_map(config) do
    get(config, key_or_keys, [], default)
  end

  defp check_value_type!(value, types, key, is_return \\ false)

  defp check_value_type!(value, types, key, is_return) when is_list(types) do
    if Enum.any?(types, &type_match?(value, &1)) do
      value
    else
      raise Pax.Config.TypeError, key: key, value: value, types: types, is_return: is_return
    end
  end

  defp check_value_type!(value, type, key, is_return) do
    if type_match?(value, type) do
      value
    else
      raise Pax.Config.TypeError, key: key, value: value, type: type, is_return: is_return
    end
  end
end
