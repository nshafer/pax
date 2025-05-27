defmodule Pax.Interface.Plugin do
  @moduledoc """
  Pax.Interface.Plugin is a behaviour for defining plugins that can be used with Pax.Interface.

  > #### `use Pax.Interface.Plugin` {: .info}
  >
  > When you `use Pax.Interface.Plugin`, your module will be declared as a behaviour for both `Pax.Plugin` as well
  > as `Pax.Interface.Plugin`.
  """

  @typedoc "A Phoenix.LiveView socket"
  @type socket :: Phoenix.LiveView.Socket.t()

  @typedoc "Unsigned params from a Phoenix.LiveView handle_params/3"
  @type unsigned_params :: Phoenix.LiveView.unsigned_params()

  @doc """
  `handle_params/4` occurs during the handle_params/3 step of the LV initialization, before the main interface handles the
  action.
  """
  @callback handle_params(opts :: map(), params :: unsigned_params(), uri :: String.t(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()}
  @doc """
  `after_params/2` occurs after all `handle_params/4` callbacks in Pax.Interface, its plugins, and the user module.
  It is called with the final params and socket, and must return a socket.
  """
  @callback after_params(opts :: map(), socket :: socket()) :: {:cont, socket()} | {:halt, socket()}

  @doc """
  `handle_event/4` occurs during the normal LV handle_event/3 callback, after the main interface action, and before the user
  module gets a chance. If it returns `{:halt, socket}` then the user module will never have its handle_event/3 called.
  If the plugin implements handle_event/4 at all, then it must return `{:cont, socket}` for any events it has no interest
  in handling, otherwise an UndefinedFunctionError will be raised.
  """
  @callback handle_event(opts :: map(), event :: binary, params :: unsigned_params(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()} | {:halt, reply :: map(), socket()}

  @doc """
  `handle_info/3` occurs during the normal LV handle_info/2 callback, after the main interface action, and before the user
  module gets a chance. If it returns `{:halt, socket}` then the user module will never have its handle_info/2 called.
  If the plugin implements handle_info/3 at all, then it must return `{:cont, socket}` for any events it has no interest
  in handling, otherwise an UndefinedFunctionError will be raised.
  """
  @callback handle_info(opts :: map(), msg :: term(), socket :: socket()) ::
              {:cont, socket()} | {:halt, socket()}

  @doc """
  `handle_async/4` occurs during the normal LV handle_async/2 callback, after the main interface action, and before the user
  module gets a chance. If it returns `{:halt, socket}` then the user module will never have its handle_async/2 called.
  If the plugin implements handle_async/4 at all, then it must return `{:cont, socket}` for any events it has no interest
  in handling, otherwise an UndefinedFunctionError will be raised.
  """
  @callback handle_async(
              opts :: map(),
              name :: term(),
              async_fun_result :: {:ok, term()} | {:exit, term()},
              socket :: socket()
            ) ::
              {:cont, socket()} | {:halt, socket()}

  @doc """
  `after_render/2` occurs after the main interface action, and before the user module gets a chance. It must always
  return a socket. Any changes to the socket will not trigger a re-render.
  """
  @callback after_render(opts :: map(), socket :: socket()) :: socket()

  @optional_callbacks handle_params: 4,
                      after_params: 2,
                      handle_event: 4,
                      handle_info: 3,
                      handle_async: 4,
                      after_render: 2

  defmacro __using__(_opts) do
    quote do
      @behaviour Pax.Plugin
      @behaviour Pax.Interface.Plugin

      def type(), do: :interface
      def init(_callback_module, _opts), do: %{}
      def config_key(), do: nil
      def config_spec(), do: %{}
      def merge_config(_opts, _config, _socket), do: %{}
      def render(_opts, _section, _assigns), do: nil
      defoverridable init: 2, config_key: 0, config_spec: 0, merge_config: 3, render: 3
    end
  end
end
