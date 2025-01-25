defmodule Pax.Adapter do
  require Logger

  @type adapter_module :: module
  @type callback_module :: module

  defstruct [:module, :callback_module, :opts]

  @type t :: %__MODULE__{}

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "Unsigned params from a Phoenix.LiveView handle_params/3"
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()

  @doc "The adapter initialization function, must return a map of initialized adapter state."
  @callback init(callback_module, opts :: []) :: map()

  @doc "A function that returns a valid Pax.Config spec for configuration keys and types accepted by the adapter."
  @callback config_spec(callback_module(), opts :: map()) :: map()

  @doc "A function that merges any additional configuration options into the adapter's state."
  @callback merge_config(callback_module(), opts :: map(), config :: map(), socket()) :: map()

  @callback default_index_fields(callback_module(), opts :: map()) :: Pax.Index.fields()

  @callback default_detail_fieldsets(callback_module(), opts :: map()) :: Pax.Detail.fieldsets()

  @callback field_type(callback_module(), opts :: map(), field_name :: atom()) ::
              {:ok, atom() | module()} | {:error, term()}

  @callback singular_name(callback_module(), opts :: map()) :: String.t()

  @callback plural_name(callback_module(), opts :: map()) :: String.t()

  @callback count_objects(callback_module(), opts :: map(), scope :: map()) :: [map()]

  @callback list_objects(callback_module(), opts :: map(), scope :: map()) :: [map()]

  @callback new_object(callback_module(), opts :: map(), socket()) :: map()

  @callback get_object(callback_module(), opts :: map(), lookup :: map(), socket()) :: map()

  @callback id_fields(callback_module(), opts :: map()) :: [atom() | binary()] | nil

  @callback object_name(callback_module(), opts :: map(), object :: map()) :: String.t()

  @callback cast(callback_module(), opts :: map(), object :: map(), unsigned_params(), fields :: list(Pax.Field.t())) ::
              Ecto.Changeset.t()

  @callback create_object(callback_module(), opts :: map(), object :: map(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @callback update_object(callback_module(), opts :: map(), object :: map(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @spec init(module(), callback_module(), opts :: []) :: t()
  def init(adapter_module, callback_module, opts \\ []) do
    %Pax.Adapter{
      module: adapter_module,
      callback_module: callback_module,
      opts: adapter_module.init(callback_module, opts)
    }
  end

  @spec config_spec(t()) :: map()
  def config_spec(%Pax.Adapter{} = adapter) do
    adapter.module.config_spec(adapter.callback_module, adapter.opts)
  end

  def merge_config(%Pax.Adapter{} = adapter, config, socket) do
    opts = adapter.module.merge_config(adapter.callback_module, adapter.opts, config, socket)
    %Pax.Adapter{adapter | opts: opts}
  end

  @spec default_index_fields(t()) :: Pax.Index.fields()
  def default_index_fields(%Pax.Adapter{} = adapter) do
    adapter.module.default_index_fields(adapter.callback_module, adapter.opts)
  end

  @spec default_detail_fieldsets(t()) :: Pax.Detail.fieldsets()
  def default_detail_fieldsets(%Pax.Adapter{} = adapter) do
    adapter.module.default_detail_fieldsets(adapter.callback_module, adapter.opts)
  end

  @spec field_type!(t(), field_name :: atom()) :: atom()
  def field_type!(%Pax.Adapter{} = adapter, field_name) do
    case adapter.module.field_type(adapter.callback_module, adapter.opts, field_name) do
      {:ok, field_type} -> field_type
      {:error, error} -> raise error
    end
  end

  @spec singular_name(t()) :: String.t()
  def singular_name(%Pax.Adapter{} = adapter) do
    adapter.module.singular_name(adapter.callback_module, adapter.opts)
  end

  @spec plural_name(t()) :: String.t()
  def plural_name(%Pax.Adapter{} = adapter) do
    adapter.module.plural_name(adapter.callback_module, adapter.opts)
  end

  @spec count_objects(t(), map()) :: [map()]
  def count_objects(%Pax.Adapter{} = adapter, scope) do
    adapter.module.count_objects(adapter.callback_module, adapter.opts, scope)
  end

  @spec list_objects(t(), map()) :: [map()]
  def list_objects(%Pax.Adapter{} = adapter, scope) do
    adapter.module.list_objects(adapter.callback_module, adapter.opts, scope)
  end

  @spec new_object(t(), socket()) :: map()
  def new_object(%Pax.Adapter{} = adapter, socket) do
    adapter.module.new_object(adapter.callback_module, adapter.opts, socket)
  end

  @spec get_object(t(), map(), socket()) :: map()
  def get_object(%Pax.Adapter{} = adapter, lookup, socket) do
    adapter.module.get_object(adapter.callback_module, adapter.opts, lookup, socket)
  end

  @spec id_fields(t()) :: [atom() | binary()] | nil
  def id_fields(%Pax.Adapter{} = adapter) do
    adapter.module.id_fields(adapter.callback_module, adapter.opts)
  end

  @spec object_name(t(), object :: map()) :: String.t()
  def object_name(%Pax.Adapter{} = adapter, object) do
    adapter.module.object_name(adapter.callback_module, adapter.opts, object)
  end

  @spec cast(t(), object :: any(), unsigned_params(), fields :: list(Pax.Field.t())) :: Ecto.Changeset.t()
  def cast(%Pax.Adapter{} = adapter, object, params, fields) do
    adapter.module.cast(adapter.callback_module, adapter.opts, object, params, fields)
  end

  @spec update_object(t(), object :: any(), Ecto.Changeset.t()) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def create_object(%Pax.Adapter{} = adapter, object, changeset) do
    adapter.module.create_object(adapter.callback_module, adapter.opts, object, changeset)
  end

  @spec update_object(t(), object :: any(), Ecto.Changeset.t()) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def update_object(%Pax.Adapter{} = adapter, object, changeset) do
    adapter.module.update_object(adapter.callback_module, adapter.opts, object, changeset)
  end
end
