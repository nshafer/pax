defmodule Pax.Interface.Plugin do
  @moduledoc """
  Pax.Interface.Plugin is a behaviour for defining plugins that can be used with Pax.Interface.

  > #### `use Pax.Interface.Plugin` {: .info}
  >
  > When you `use Pax.Interface.Plugin`, your module will be declared as a behaviour for both `Pax.Plugin` as well
  > as `Pax.Interface.Plugin`. It will also import some convenience functions from `Pax.Plugin`.
  """

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "Unsigned params from a Phoenix.LiveView handle_params/3"
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()

  @doc """
  on_preload occurs during the handle_params/3 step of the LV initialization, before the main interface handles the
  action.
  """
  @callback on_preload(opts :: map(), params :: unsigned_params(), uri :: String.t(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()}
  @doc """
  on_loaded occurs during the handle_params/3 step of the LV initialization, after the main interface handles the
  action, right before the user module's handle_params/3 is finally called..
  """
  @callback on_loaded(opts :: map(), params :: unsigned_params(), uri :: String.t(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()}

  @doc """
  on_event occurs during the normal LV handle_event/3 callback, after the main interface action, and before the user
  module gets a chance. If it returns `{:halt, socket}` then the user module will never have its handle_event/3 called.
  If the plugin implements on_event/4 at all, then it must return `{:cont, socket}` for any events it has no interest
  in handling, otherwise an UndefinedFunctionError will be raised.
  """
  @callback on_event(event :: binary, opts :: map(), params :: unsigned_params(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()} | {:halt, reply :: map(), socket()}

  @optional_callbacks on_preload: 4, on_loaded: 4, on_event: 4

  # TODO: add on_info() callback

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Plugin
      @behaviour Pax.Interface.Plugin
      import Pax.Plugin

      def type(), do: :interface
      def init(_callback_module, _opts), do: %{}
      def config_key(), do: nil
      def config_spec(), do: %{}
      def merge_config(_opts, _config, _socket), do: %{}
      def render_component(_opts, _section, _assigns), do: nil
      defoverridable init: 2, config_key: 0, config_spec: 0, merge_config: 3, render_component: 3
    end
  end
end
