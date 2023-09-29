defmodule Pax.Adapter do
  require Logger

  @type adapter :: module
  @type callback_module :: module

  defstruct [:adapter, :callback_module, :opts]

  @type t :: %__MODULE__{
          adapter: adapter(),
          callback_module: callback_module(),
          opts: map()
        }

  @type unsigned_params :: Phoenix.LiveView.unsigned_params()
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(callback_module, opts :: []) :: map()

  @callback default_index_fields(callback_module(), opts :: map()) :: Pax.Index.fields()

  @callback default_detail_fieldsets(callback_module(), opts :: map()) :: Pax.Detail.fieldsets()

  @callback field_type(callback_module(), opts :: map(), field_name :: atom()) ::
              {:ok, atom() | module()} | {:error, term()}

  @callback singular_name(callback_module(), opts :: map()) :: String.t()

  @callback plural_name(callback_module(), opts :: map()) :: String.t()

  @callback list_objects(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: [map()]

  @callback new_object(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: map()

  @callback get_object(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: map()

  @callback object_id(callback_module(), opts :: map(), object :: map()) :: String.Chars.t()

  @callback object_name(callback_module(), opts :: map(), object :: map()) :: String.t()

  @callback cast(callback_module(), opts :: map(), object :: map(), unsigned_params(), fields :: list(Pax.Field.t())) ::
              Ecto.Changeset.t()

  @callback create_object(callback_module(), opts :: map(), object :: map(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @callback update_object(callback_module(), opts :: map(), object :: map(), Ecto.Changeset.t()) ::
              {:ok, map()} | {:error, Ecto.Changeset.t()}

  @spec init(adapter(), callback_module(), opts :: []) :: t()
  def init(adapter, callback_module, opts \\ []) do
    %Pax.Adapter{
      adapter: adapter,
      callback_module: callback_module,
      opts: adapter.init(callback_module, opts)
    }
  end

  @spec default_index_fields(t()) :: Pax.Index.fields()
  def default_index_fields(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}) do
    adapter.default_index_fields(callback_module, opts)
  end

  @spec default_detail_fieldsets(t()) :: Pax.Detail.fieldsets()
  def default_detail_fieldsets(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}) do
    adapter.default_detail_fieldsets(callback_module, opts)
  end

  @spec field_type!(t(), field_name :: atom()) :: atom()
  def field_type!(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, field_name) do
    case adapter.field_type(callback_module, opts, field_name) do
      {:ok, field_type} -> field_type
      {:error, error} -> raise error
    end
  end

  @spec singular_name(t()) :: String.t()
  def singular_name(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}) do
    adapter.singular_name(callback_module, opts)
  end

  @spec plural_name(t()) :: String.t()
  def plural_name(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}) do
    adapter.plural_name(callback_module, opts)
  end

  @spec list_objects(t(), unsigned_params(), String.t(), socket()) :: [map()]
  def list_objects(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.list_objects(callback_module, opts, params, uri, socket)
  end

  @spec new_object(t(), unsigned_params(), String.t(), socket()) :: map()
  def new_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.new_object(callback_module, opts, params, uri, socket)
  end

  @spec get_object(t(), unsigned_params(), String.t(), socket()) :: map()
  def get_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.get_object(callback_module, opts, params, uri, socket)
  end

  @spec object_id(t(), object :: map()) :: String.Chars.t()
  def object_id(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, object) do
    adapter.object_id(callback_module, opts, object)
  end

  @spec object_name(t(), object :: map()) :: String.t()
  def object_name(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, object) do
    adapter.object_name(callback_module, opts, object)
  end

  # TODO: rename to cast() which gets a list of fields that are not dynamic/computed or marked immutable, and it returns
  # a changeset with those fields cast from params, but no validation is done (yet.)
  @spec cast(t(), object :: any(), unsigned_params(), fields :: list(Pax.Field.t())) :: Ecto.Changeset.t()
  def cast(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, object, params, fields) do
    adapter.cast(callback_module, opts, object, params, fields)
  end

  @spec update_object(t(), object :: any(), Ecto.Changeset.t()) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def create_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, object, changeset) do
    adapter.create_object(callback_module, opts, object, changeset)
  end

  @spec update_object(t(), object :: any(), Ecto.Changeset.t()) :: {:ok, any()} | {:error, Ecto.Changeset.t()}
  def update_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, object, changeset) do
    adapter.update_object(callback_module, opts, object, changeset)
  end
end
