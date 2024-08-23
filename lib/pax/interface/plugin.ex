defmodule Pax.Interface.Plugin do
  @doc """
  on_preload occurs during the handle_params/3 step of the LV initialization, before the main interface handles the
  action.
  """
  @callback on_preload(
              opts :: keyword(),
              params :: Phoenix.LiveView.unsigned_params(),
              uri :: String.t(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @doc """
  on_loaded occurs during the handle_params/3 step of the LV initialization, after the main interface handles the
  action, right before the user module's handle_params/3 is finally called..
  """
  @callback on_loaded(
              opts :: keyword(),
              params :: Phoenix.LiveView.unsigned_params(),
              uri :: String.t(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:cont, Phoenix.LiveView.Socket.t()} | {:halt, Phoenix.LiveView.Socket.t()}

  @doc """
  on_event occurs during the normal LV handle_event/3 callback, after the main interface action, and before the user
  module gets a chance. If it returns `{:halt, socket}` then the user module will never have its handle_event/3 called.
  If the plugin implements on_event/4 at all, then it must return `{:cont, socket}` for any events it has no interest
  in handling, otherwise an UndefinedFunctionError will be raised.
  """
  @callback on_event(
              event :: binary,
              opts :: keyword(),
              params :: Phoenix.LiveView.unsigned_params(),
              socket :: Phoenix.LiveView.Socket.t()
            ) ::
              {:cont, Phoenix.LiveView.Socket.t()}
              | {:halt, Phoenix.LiveView.Socket.t()}
              | {:halt, reply :: map(), Phoenix.LiveView.Socket.t()}

  @optional_callbacks on_preload: 4, on_loaded: 4, on_event: 4

  # TODO: add on_info() callback

  @callback index_header_primary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback index_header_secondary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback index_header_tertiary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @optional_callbacks index_header_primary: 1, index_header_secondary: 1, index_header_tertiary: 1

  @callback index_footer_primary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback index_footer_secondary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback index_footer_tertiary(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @optional_callbacks index_footer_primary: 1, index_footer_secondary: 1, index_footer_tertiary: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Plugin
      @behaviour Pax.Interface.Plugin
      import Pax.Plugin

      def type(), do: :interface
    end
  end
end
