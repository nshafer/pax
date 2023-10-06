defmodule Pax.Field.Type do
  @moduledoc """
  A field type is a module that implements the Pax.Field.Type behaviour. It is responsible for rendering a Pax.Field
  and other related behavior
  """

  @callback init(opts :: keyword()) :: map()
  @callback render(opts :: map(), value :: any()) :: String.t() | Phoenix.LiveView.Rendered.t() | nil
  @callback input(opts :: map(), Pax.Field.field(), form_field :: Phoenix.HTML.FormField.t()) ::
              String.t() | Phoenix.LiveView.Rendered.t() | nil
  @callback immutable?(opts :: map()) :: boolean()

  @optional_callbacks input: 3, immutable?: 1
end
