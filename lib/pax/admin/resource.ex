defmodule Pax.Admin.Resource do
  @type field() :: {atom(), atom() | module()} | {atom(), atom() | module(), keyword()}

  @callback pax_adapter(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {module(), keyword()}

  @callback pax_index_fields(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: list(field())

  @callback pax_detail_fieldsets(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: list(field()) | list(list(field) | field()) | keyword(list(field))

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Admin.Resource
    end
  end
end
