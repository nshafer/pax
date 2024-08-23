defmodule Pax.Admin.Resource do
  @type t() :: %__MODULE__{
          name: atom(),
          path: String.t(),
          label: String.t(),
          section: Pax.Admin.Section.t(),
          mod: module(),
          opts: Keyword.t()
        }

  @enforce_keys [:name, :path, :label, :mod, :opts]
  defstruct [:name, :path, :label, :section, :mod, :opts]

  # TODO: add @callback render()

  @callback pax_init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback singular_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback plural_name(socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil
  @callback object_name(object :: map(), socket :: Phoenix.LiveView.Socket.t()) :: String.t() | nil

  @callback index_fields(socket :: Phoenix.LiveView.Socket.t()) :: list(Pax.Field.field()) | nil

  @callback fieldsets(socket :: Phoenix.LiveView.Socket.t()) ::
              list(Pax.Field.field())
              | list(list(Pax.Field.field()) | Pax.Field.field())
              | keyword(list(Pax.Field.field()))
              | nil

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Admin.Resource

      def pax_init(_params, _session, socket), do: {:cont, socket}

      def plugins(_socket) do
        [
          Pax.Plugins.Pagination
        ]
      end

      def singular_name(_socket), do: nil
      def plural_name(_socket), do: nil
      def object_name(_object, _socket), do: nil

      def index_fields(_socket), do: nil
      def fieldsets(_socket), do: nil

      defoverridable pax_init: 3,
                     plugins: 1,
                     singular_name: 1,
                     plural_name: 1,
                     object_name: 2,
                     index_fields: 1,
                     fieldsets: 1
    end
  end
end
