defmodule Pax.Adapter do
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

  @spec list_objects(t(), unsigned_params(), String.t(), socket()) :: [map()]
  def list_objects(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.list_objects(callback_module, opts, params, uri, socket)
  end

  @spec get_object(t(), unsigned_params(), String.t(), socket()) :: map()
  def get_object(%Pax.Adapter{adapter: adapter, callback_module: callback_module, opts: opts}, params, uri, socket) do
    adapter.get_object(callback_module, opts, params, uri, socket)
  end
end
