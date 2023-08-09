defmodule Pax.Adapter do
  @type live_module :: module
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(live_module, opts :: []) :: map()
  @callback list_objects(live_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: [map()]
  @callback get_object(live_module(), opts :: map(), unsigned_params(), uri :: String.t(), socket()) :: map()
end
