defmodule Pax.Adapter do
  @type callback_module :: module
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(callback_module, opts :: []) :: map()
  @callback list_objects(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: [map()]
  @callback get_object(callback_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: map()
end
