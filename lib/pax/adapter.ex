defmodule Pax.Adapter do
  alias Pax.Interface
  require Logger

  @type adapter_module :: module
  @type callback_module :: module

  defstruct [:module, :opts]

  @type t :: %__MODULE__{}

  @type opts ::
          binary()
          | tuple()
          | atom()
          | integer()
          | float()
          | [opts()]
          | %{optional(opts()) => opts()}
          | MapSet.t()

  @type lookup :: %{atom() => any()}
  @type scope :: %{atom() => any()}

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "Unsigned params from a Phoenix.LiveView handle_params/3"
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()

  @doc "The adapter initialization function, must return a map of initialized adapter state."
  @callback init(callback_module, opts :: []) :: opts()

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the adapter."
  @callback config_spec(opts()) :: map()

  @doc "A function that merges any additional configuration options into the adapter's opts map."
  @callback merge_config(opts(), config :: map(), socket()) :: map()

  @callback default_fields(opts()) :: Pax.Index.fields()

  @callback field_type(opts(), field_name :: atom()) ::
              {:ok, atom() | module()} | {:error, term()}

  @callback singular_name(opts()) :: String.t()

  @callback plural_name(opts()) :: String.t()

  @callback count_objects(opts(), scope()) :: integer()

  @callback list_objects(opts(), scope()) :: [Interface.object()]

  @callback new_object(opts(), socket()) :: Interface.object()

  @callback get_object(opts(), lookup(), scope(), socket()) :: Interface.object()

  @callback id_fields(opts()) :: [atom()] | nil

  @callback object_ids(opts(), Interface.object()) :: [String.Chars.t()] | nil

  @callback object_name(opts(), Interface.object()) :: String.t() | nil

  @callback change_object(opts(), Interface.object(), unsigned_params(), fields :: [Pax.Field.t()]) ::
              Ecto.Changeset.t()

  @callback create_object(opts(), Interface.object(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @callback update_object(opts(), Interface.object(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @spec init(module(), opts :: []) :: t()
  def init(adapter_module, callback_module, opts \\ []) do
    %Pax.Adapter{
      module: adapter_module,
      opts: adapter_module.init(callback_module, opts)
    }
  end

  @spec adapter?(term()) :: boolean()
  def adapter?(%Pax.Adapter{}), do: true
  def adapter?(_), do: false

  @spec config_spec(t()) :: map()
  def config_spec(%Pax.Adapter{} = adapter) do
    adapter.module.config_spec(adapter.opts)
  end

  def merge_config(%Pax.Adapter{} = adapter, config, socket) do
    opts = adapter.module.merge_config(adapter.opts, config, socket)
    %Pax.Adapter{adapter | opts: opts}
  end

  @spec default_fields(t()) :: Pax.Index.fields()
  def default_fields(%Pax.Adapter{} = adapter) do
    adapter.module.default_fields(adapter.opts)
  end

  @spec field_type!(t(), field_name :: atom()) :: atom()
  def field_type!(%Pax.Adapter{} = adapter, field_name) do
    case adapter.module.field_type(adapter.opts, field_name) do
      {:ok, field_type} -> field_type
      {:error, error} -> raise error
    end
  end

  # TODO: Make this always return a list, return [:id] if adapter returns nil. Remove `init_adapter_id_fields`
  @spec id_fields(t()) :: [atom()] | nil
  def id_fields(%Pax.Adapter{} = adapter) do
    adapter.module.id_fields(adapter.opts)
  end

  @spec object_ids(t(), Interface.object()) :: [String.Chars.t()]
  def object_ids(%Pax.Adapter{} = adapter, object) do
    case adapter.module.object_ids(adapter.opts, object) do
      nil -> default_object_ids(adapter, object)
      ids when is_list(ids) -> ids
      _ -> raise ArgumentError, "object_ids must return a list or nil"
    end
  end

  # TODO: Make this always return a string, return "Object" if adapter returns nil. Remove `init_adapter_singular_name`
  @spec singular_name(t()) :: String.t() | nil
  def singular_name(%Pax.Adapter{} = adapter) do
    adapter.module.singular_name(adapter.opts)
  end

  # TODO: Make this always return a string, return "Objects" if adapter returns nil. Remove `init_adapter_plural_name`
  @spec plural_name(t()) :: String.t() | nil
  def plural_name(%Pax.Adapter{} = adapter) do
    adapter.module.plural_name(adapter.opts)
  end

  @spec count_objects(t(), scope()) :: integer()
  def count_objects(%Pax.Adapter{} = adapter, scope) do
    adapter.module.count_objects(adapter.opts, scope)
  end

  @spec list_objects(t(), scope()) :: [Interface.object()]
  def list_objects(%Pax.Adapter{} = adapter, scope) do
    adapter.module.list_objects(adapter.opts, scope)
  end

  @spec new_object(t(), socket()) :: Interface.object()
  def new_object(%Pax.Adapter{} = adapter, socket) do
    adapter.module.new_object(adapter.opts, socket)
  end

  @spec get_object(t(), lookup(), scope(), socket()) :: Interface.object()
  def get_object(%Pax.Adapter{} = adapter, lookup, scope, socket) do
    adapter.module.get_object(adapter.opts, lookup, scope, socket)
  end

  # TODO: Make this always return a string, return nil if adapter returns nil. Remove `init_adapter_object_name`
  @spec object_name(t(), Interface.object()) :: String.t() | nil
  def object_name(%Pax.Adapter{} = adapter, object) do
    adapter.module.object_name(adapter.opts, object)
  end

  @spec change_object(t(), Interface.object(), unsigned_params(), fields :: [Pax.Field.t()]) :: Ecto.Changeset.t()
  def change_object(%Pax.Adapter{} = adapter, object, params, fields) do
    adapter.module.change_object(adapter.opts, object, params, fields)
  end

  @spec update_object(t(), Interface.object(), Ecto.Changeset.t()) ::
          {:ok, any()} | {:error, Ecto.Changeset.t()}
  def create_object(%Pax.Adapter{} = adapter, object, changeset) do
    adapter.module.create_object(adapter.opts, object, changeset)
  end

  @spec update_object(t(), Interface.object(), Ecto.Changeset.t()) ::
          {:ok, any()} | {:error, Ecto.Changeset.t()}
  def update_object(%Pax.Adapter{} = adapter, object, changeset) do
    adapter.module.update_object(adapter.opts, object, changeset)
  end

  defp default_object_ids(adapter, object) do
    case id_fields(adapter) do
      nil -> []
      id_fields -> Enum.map(id_fields, fn field -> Map.fetch!(object, field) end)
    end
  end
end
