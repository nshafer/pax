defmodule Pax.Detail.Adapter do
  @type live_module :: module
  @type unsigned_params :: map
  @type socket :: Phoenix.LiveView.Socket.t()

  @callback init(live_module(), opts :: []) :: any()
  @callback get_object(live_module(), opts :: any(), unsigned_params(), uri :: String.t(), socket()) :: map()
end
