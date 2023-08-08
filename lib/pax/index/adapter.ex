defmodule Pax.Index.Adapter do
  @type live_module :: module
  @type unsigned_params :: map
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(live_module :: module(), opts :: []) :: any()
  @callback list_objects(live_module(), opts :: any(), unsigned_params(), uri :: String.t(), socket()) :: [map()]
end
