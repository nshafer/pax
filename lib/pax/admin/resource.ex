defmodule Pax.Admin.Resource do
  @moduledoc """
  A resource in a `Pax.Admin`, which is a `Pax.Interface` for one kind of object.

      defmodule MyAppWeb.Admin.BookResource do
        use Pax.Admin.Resource

        def adapter(_socket) do
          {Pax.Adapters.EctoSchema, repo: MyApp.Repo, schema: MyApp.Library.Book}
        end

        def config(_socket) do
          [fields: [{:title, link: true}, :author, :published_on]]
        end
      end

  The callbacks mirror those of `Pax.Interface`, without the `pax_` prefix, and all of them have defaults. The
  data callbacks are optional: define one to load or persist objects yourself, or leave it out and let the
  configured `Pax.Adapter` answer. With neither, Pax raises.

  Every data callback receives the socket, and `socket.assigns.pax` is a `%Pax.Interface{}` holding the fields,
  object, action, criteria and config for the current request - see `Pax.Interface` for the full list, and
  `Pax.Adapter` for how to resolve per-call values such as an actor or a tenant.
  """

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

  @doc """
  Renders this resource's pages, replacing the default and the admin's `c:Pax.Admin.render_resource/1`.
  """
  @callback render(assigns :: map()) :: Phoenix.LiveView.Rendered.t()

  @optional_callbacks render: 1

  # Pax.Interface callbacks

  @doc """
  Called when a resource page mounts, before Pax is initialized. Returns the same values as `c:Pax.Interface.pax_init/3`.
  """
  @callback init(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:cont, Phoenix.LiveView.Socket.t()}
              | {:skip, Phoenix.LiveView.Socket.t()}
              | {:halt, Phoenix.LiveView.Socket.t()}

  @callback adapter(socket :: Phoenix.LiveView.Socket.t()) ::
              module() | {module(), keyword()} | {module(), module(), keyword()}

  @callback plugins(socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Plugin.pluginspec()]

  @callback config(socket :: Phoenix.LiveView.Socket.t()) :: keyword() | map()

  # Pax.Interface.Index callbacks

  @callback count_objects(criteria :: map(), socket :: Phoenix.LiveView.Socket.t()) :: non_neg_integer()
  @callback list_objects(criteria :: map(), socket :: Phoenix.LiveView.Socket.t()) :: [Pax.Interface.object()]

  @optional_callbacks [
    count_objects: 2,
    list_objects: 2
  ]

  # Pax.Interface.Detail callbacks

  @callback new_object(socket :: Phoenix.LiveView.Socket.t()) :: Pax.Interface.object()
  @callback get_object(lookup :: map(), criteria :: map(), socket :: Phoenix.LiveView.Socket.t()) ::
              Pax.Interface.object()
  @callback change_object(
              object :: Pax.Interface.object(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Pax.Adapter.form_data()
  @callback validate_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: Pax.Adapter.form_data()
  @callback create_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Pax.Adapter.form_data()}
  @callback update_object(
              object :: Pax.Interface.object(),
              form_data :: Pax.Adapter.form_data(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:ok, Pax.Interface.object()} | {:error, Pax.Adapter.form_data()}

  @optional_callbacks [
    new_object: 1,
    get_object: 3,
    change_object: 2,
    validate_object: 4,
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

      def count_objects(_criteria, _socket), do: :not_implemented
      def list_objects(_criteria, _socket), do: :not_implemented

      defoverridable count_objects: 2, list_objects: 2

      # Pax.Interface.Detail callbacks

      def new_object(_socket), do: :not_implemented
      def get_object(_lookup, _criteria, _socket), do: :not_implemented
      def change_object(_object, _socket), do: :not_implemented
      def validate_object(_object, _form_data, _params, _socket), do: :not_implemented
      def create_object(_object, _form_data, _params, _socket), do: :not_implemented
      def update_object(_object, _form_data, _params, _socket), do: :not_implemented

      defoverridable new_object: 1,
                     get_object: 3,
                     change_object: 2,
                     validate_object: 4,
                     create_object: 4,
                     update_object: 4
    end
  end
end
