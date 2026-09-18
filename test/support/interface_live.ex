defmodule PaxTest.InterfaceLive do
  @moduledoc """
  A LiveView using Pax.Interface where every callback is configured by the running test through `PaxTest.Owner`.

  Callbacks that aren't configured behave like the defaults injected by `use Pax.Interface`. The LiveView's own
  `handle_*` callbacks report to the test, so tests can check whether Pax halted or continued the hook chain.
  """
  use Phoenix.LiveView
  use Pax.Interface

  alias PaxTest.Owner

  def render(assigns) do
    ~H"""
    <div id="flash-info">{Phoenix.Flash.get(@flash, :info)}</div>
    <Pax.Interface.Components.pax_interface :if={assigns[:pax]} pax={@pax} />
    <div :if={!assigns[:pax]} id="no-pax">Pax was not initialized</div>
    """
  end

  def mount(params, session, socket) do
    Owner.call(:mount, [params, session, socket], {:ok, socket})
  end

  def pax_init(params, session, socket), do: Owner.call(:pax_init, [params, session, socket], {:cont, socket})
  def pax_adapter(socket), do: Owner.call(:pax_adapter, [socket], nil)
  def pax_plugins(socket), do: Owner.call(:pax_plugins, [socket], [])
  def pax_config(socket), do: Owner.call(:pax_config, [socket], [])

  def count_objects(criteria, socket), do: Owner.call(:count_objects, [criteria, socket], :not_implemented)
  def list_objects(criteria, socket), do: Owner.call(:list_objects, [criteria, socket], :not_implemented)
  def new_object(socket), do: Owner.call(:new_object, [socket], :not_implemented)
  def get_object(lookup, criteria, socket), do: Owner.call(:get_object, [lookup, criteria, socket], :not_implemented)

  def change_object(object, params, socket),
    do: Owner.call(:change_object, [object, params, socket], :not_implemented)

  def create_object(object, changeset, socket),
    do: Owner.call(:create_object, [object, changeset, socket], :not_implemented)

  def update_object(object, changeset, socket),
    do: Owner.call(:update_object, [object, changeset, socket], :not_implemented)

  def handle_params(params, uri, socket) do
    Owner.notify({:user_handle_params, params, uri})
    {:noreply, socket}
  end

  def handle_event("start_async", %{"result" => result}, socket) do
    {:noreply, start_async(socket, :test_task, fn -> result end)}
  end

  def handle_event(event, params, socket) do
    Owner.notify({:user_handle_event, event, params})
    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    Owner.notify({:user_handle_info, msg})
    {:noreply, socket}
  end

  def handle_async(name, result, socket) do
    Owner.notify({:user_handle_async, name, result})
    {:noreply, socket}
  end
end

defmodule PaxTest.SpyPlugin do
  @moduledoc """
  An interface plugin that reports every callback to the test, and renders a marker into every section.

  Options:
    * `:halt` - a list of callbacks (`:handle_params`, `:after_params`, `:handle_event`, `:handle_info`,
      `:handle_async`) that return `{:halt, socket}` instead of `{:cont, socket}`.
  """
  use Pax.Interface.Plugin
  use Phoenix.Component

  alias PaxTest.Owner

  @impl true
  def init(callback_module, opts) do
    opts = Pax.Options.validate!(opts, [halt: [type: {:list, :atom}, default: []]], "plugin #{inspect(__MODULE__)}")
    Owner.notify({:spy, :init, callback_module, opts})
    %{halt: opts[:halt]}
  end

  @impl true
  def config_key(), do: :spy

  @impl true
  def config_spec(), do: %{label: [:string, {:function, 1, :string}]}

  @impl true
  def merge_config(opts, config, socket) do
    Map.put(opts, :label, Pax.Config.get(config, :label, [socket], "spy"))
  end

  @impl true
  def handle_params(opts, params, uri, socket) do
    Owner.notify({:spy, :handle_params, params, uri, socket.assigns.pax.action})
    result(opts, :handle_params, socket)
  end

  @impl true
  def after_params(opts, socket) do
    Owner.notify({:spy, :after_params, socket.assigns.pax})
    result(opts, :after_params, socket)
  end

  @impl true
  def handle_event(_opts, "spy_reply", params, socket) do
    Owner.notify({:spy, :handle_event, "spy_reply", params})
    {:halt, %{replied: true}, socket}
  end

  def handle_event(opts, event, params, socket) do
    Owner.notify({:spy, :handle_event, event, params})
    result(opts, :handle_event, socket)
  end

  @impl true
  def handle_info(opts, msg, socket) do
    Owner.notify({:spy, :handle_info, msg})
    result(opts, :handle_info, socket)
  end

  @impl true
  def handle_async(opts, name, async_fun_result, socket) do
    Owner.notify({:spy, :handle_async, name, async_fun_result})
    result(opts, :handle_async, socket)
  end

  @impl true
  def after_render(_opts, socket) do
    Owner.notify({:spy, :after_render, socket.assigns.pax})
    socket
  end

  @impl true
  def render(opts, section, assigns) do
    assigns = assign(assigns, section: section, label: opts.label)

    ~H"""
    <span class="spy" data-section={@section}>{@label}</span>
    """
  end

  defp result(opts, callback, socket) do
    if callback in opts.halt, do: {:halt, socket}, else: {:cont, socket}
  end
end

defmodule PaxTest.BarePlugin do
  @moduledoc "An interface plugin that relies entirely on the defaults from `use Pax.Interface.Plugin`."
  use Pax.Interface.Plugin
end
