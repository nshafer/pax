defmodule Pax.Options do
  @moduledoc ~S"""
  Validates the options given to a plugin, adapter or field type against a `NimbleOptions` schema.

  Pax passes options through to `init` exactly as the developer gave them, so validating them is up to you. Every
  built-in plugin, adapter and field type validates its options with this module:

      defmodule MyPlugin do
        use Pax.Interface.Plugin

        @opts_schema NimbleOptions.new!(
                       placement: [type: :atom, default: :index_body, doc: "The section to render in."]
                     )

        @moduledoc \"""
        Renders something useful.

        ## Options

        #{NimbleOptions.docs(@opts_schema)}
        \"""

        @impl true
        def init(_callback_module, opts) do
          opts
          |> Pax.Options.validate!(@opts_schema, "plugin #{inspect(__MODULE__)}")
          |> Map.new()
        end
      end

  Declaring the schema in a module attribute lets the moduledoc document the options with
  `NimbleOptions.docs(@opts_schema)`, which is how the built-in modules document theirs. The attribute has to be set
  before the moduledoc that interpolates it.

  Options are fixed when the plugin, adapter or field is initialized, so a function given as an option is a plain
  value, never called with the socket. Configuration that is resolved per socket goes through `Pax.Config` instead.
  """

  @doc """
  Validates `opts` against `schema`, returning them with the schema's defaults filled in.

  The `context` names what is being configured, such as `"plugin MyApp.MyPlugin"`, and is included in errors.

  Raises an `ArgumentError` when `opts` is not a keyword list, when it doesn't match the `schema`, or when `schema` is
  not a `NimbleOptions` schema.

      iex> Pax.Options.validate!([limit: 10], [limit: [type: :integer]], "plugin MyPlugin")
      [limit: 10]

      iex> Pax.Options.validate!([], [limit: [type: :integer, default: 25]], "plugin MyPlugin")
      [limit: 25]
  """
  @spec validate!(keyword(), NimbleOptions.t() | keyword(), String.t()) :: keyword()
  def validate!(opts, schema, context) when is_binary(context) do
    if not (is_list(schema) or is_struct(schema, NimbleOptions)) do
      raise ArgumentError,
            "Invalid options schema for #{context}, expected a NimbleOptions schema, got: #{inspect(schema)}"
    end

    if not Keyword.keyword?(opts) do
      raise ArgumentError, "Invalid options for #{context}, expected a keyword list, got: #{inspect(opts)}"
    end

    case NimbleOptions.validate(opts, schema) do
      {:ok, opts} ->
        opts

      {:error, %NimbleOptions.ValidationError{} = error} ->
        raise ArgumentError, "Invalid options for #{context}: #{Exception.message(error)}"
    end
  end
end
