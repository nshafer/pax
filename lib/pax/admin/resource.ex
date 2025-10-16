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

  # Pax.Interface callbacks

  @callback init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @callback adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback config(socket :: Phoenix.LiveView.Socket.t()) :: keyword() | map()

  # Pax.Interface.Index callbacks

  @callback count_objects(scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: non_neg_integer()
  @callback list_objects(scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Interface.object()]

  @optional_callbacks [
    count_objects: 2,
    list_objects: 2
  ]

  # Pax.Interface.Detail callbacks

  @callback new_object(socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback get_object(lookup :: map(), scope :: map(), socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback change_object(
              object :: Pax.Interface.object(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Ecto.Changeset.t()
  @callback create_object(
              object :: Pax.Interface.object(),
              changeset :: Ecto.Changeset.t(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Ecto.Changeset.t()}
  @callback update_object(
              object :: Pax.Interface.object(),
              changeset :: Ecto.Changeset.t(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Ecto.Changeset.t()}

  @optional_callbacks [
    new_object: 1,
    get_object: 3,
    change_object: 3,
    create_object: 4,
    update_object: 4
  ]

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Admin.Resource

      # Pax.Interface callbacks

      def init(_params, _session, socket), do: {:cont, socket}

      def adapter(_socket), do: nil

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

      defoverridable init: 3, adapter: 1, plugins: 1, config: 1

      # Pax.Interface.Index callbacks

      def count_objects(_scope, _socket), do: :not_implemented
      def list_objects(_scope, _socket), do: :not_implemented

      defoverridable count_objects: 2, list_objects: 2

      # Pax.Interface.Detail callbacks

      def new_object(_socket), do: :not_implemented
      def get_object(_lookup, _scope, _socket), do: :not_implemented
      def change_object(_object, _params, _socket), do: :not_implemented
      def create_object(_object, _changeset, _params, _socket), do: :not_implemented
      def update_object(_object, _changeset, _params, _socket), do: :not_implemented

      defoverridable new_object: 1, get_object: 3, change_object: 3, create_object: 4, update_object: 4
    end
  end
end
