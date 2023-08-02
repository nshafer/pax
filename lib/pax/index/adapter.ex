defmodule Pax.Index.Adapter do
  @type unsigned_params :: map

  @callback init(live_module :: module(), opts :: []) :: any()

  @callback list_objects(opts :: any(), socket :: Phoenix.LiveView.Socket.t()) :: [map()]
end
