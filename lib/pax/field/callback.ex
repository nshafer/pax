defmodule Pax.Field.Callback do
  @callback pax_field_link(object :: map()) :: String.t()
  @callback pax_field_link(object :: map(), opts :: keyword()) :: String.t()

  @optional_callbacks pax_field_link: 1, pax_field_link: 2
end
