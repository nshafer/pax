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

  @type field :: Pax.Field.field()
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(callback_module, opts :: []) :: map()
  @callback default_index_fields(callback_module(), opts :: map()) :: [field()]
  @callback default_detail_fieldsets(callback_module(), opts :: map()) ::
              list(field()) | list(list(field) | field()) | keyword(list(field))
  @callback field_type(callback_module(), opts :: map(), field_name :: atom()) ::
              {:ok, atom() | module()} | {:error, term()}
  @callback list_objects(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: [map()]
  @callback get_object(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: map()

  @spec init(adapter(), callback_module(), opts :: []) :: t()
  def init(adapter, callback_module, opts \\ []) do
    %Pax.Adapter{
      adapter: adapter,
      callback_module: callback_module,
      opts: adapter.init(callback_module, opts)
    }
  end

  @spec default_index_fields(t()) :: [field()]
  def default_index_fields(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}) do
    adapter.default_index_fields(callback_module, opts)
  end

  @spec default_detail_fieldsets(t()) :: list(field()) | list(list(field) | field()) | keyword(list(field))
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

  @spec list_objects(t(), unsigned_params(), String.t(), socket()) :: [map()]
  def list_objects(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.list_objects(callback_module, opts, params, uri, socket)
  end

  @spec get_object(t(), unsigned_params(), String.t(), socket()) :: map()
  def get_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.get_object(callback_module, opts, params, uri, socket)
  end
end
