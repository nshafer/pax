defmodule Pax.Admin.Resource do
  @derive {Phoenix.Param, key: :path}

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

  @callback init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback config(socket :: Phoenix.LiveView.Socket.t()) :: keyword() | map()

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Admin.Resource

      def init(_params, _session, socket), do: {:cont, socket}

      def plugins(_socket) do
        [
          Pax.Plugins.Title,
          {Pax.Plugins.Pagination, objects_per_page: 100},
          Pax.Plugins.IndexTable,
          Pax.Plugins.DetailList,
          Pax.Plugins.ActionButtons
        ]
      end

      def config(_socket), do: []

      defoverridable init: 3,
                     plugins: 1,
                     config: 1
    end
  end
end
