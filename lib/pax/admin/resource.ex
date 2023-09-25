defmodule Pax.Admin.Resource do
  # TODO: rename "name" to "key" and add singular and plural names
  @type t() :: %__MODULE__{
          name: atom(),
          path: String.t(),
          title: String.t(),
          section: Pax.Admin.Section.t(),
          mod: module(),
          opts: Keyword.t()
        }

  @enforce_keys [:name, :path, :title, :mod, :opts]
  defstruct [:name, :path, :title, :section, :mod, :opts]

  @callback pax_adapter(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: {module(), keyword()}

  @callback pax_index_fields(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) :: list(Pax.Field.field()) | nil

  @callback pax_detail_fieldsets(
              params :: Phoenix.LiveView.unsigned_params() | :not_mounted_at_router,
              session :: map(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              list(Pax.Field.field())
              | list(list(Pax.Field.field()) | Pax.Field.field())
              | keyword(list(Pax.Field.field()))
              | nil

  # TODO: rename this to pax_field_link to show it's a passthrough
  @callback index_link(object :: map()) :: String.t()
  @callback index_link(object :: map(), resource :: map()) :: String.t()

  # TODO: remove this in favor of singular, plural, object names
  @callback detail_title(object :: map()) :: String.t()
  @callback object_name(socket :: Phoenix.LiveView.Socket.t(), object :: map()) :: String.t()

  @optional_callbacks pax_index_fields: 3,
                      pax_detail_fieldsets: 3,
                      index_link: 1,
                      index_link: 2,
                      detail_title: 1,
                      object_name: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Admin.Resource
    end
  end
end
