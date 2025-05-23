defmodule Pax.Plugins.NewButton do
  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  @default_placement :index_header_secondary
  @default_truncate_length 25

  @impl true
  def init(_callback_module, opts) do
    %{
      placement: Keyword.get(opts, :placement, @default_placement),
      truncate_length: Keyword.get(opts, :truncate_length, @default_truncate_length)
    }
  end

  @impl true
  def config_key(), do: :new_button

  @impl true
  def config_spec() do
    %{
      placement: [:atom, :list, {:function, 1, [:atom, :list]}],
      truncate_length: [:integer, {:function, 1, :integer}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      placement: Pax.Config.get(config, :placement, [socket], opts.placement),
      truncate_length: Pax.Config.get(config, :truncate_length, [socket], opts.truncate_length)
    }
  end

  @impl true
  def render(%{placement: placement} = opts, placement, assigns),
    do: new_button(opts, assigns)

  def render(%{placement: placement} = opts, section, assigns) when is_list(placement) do
    if Enum.member?(placement, section) do
      new_button(opts, assigns)
    else
      nil
    end
  end

  def render(_opts, _section, _assigns), do: nil

  def new_button(opts, assigns) do
    assigns = assign(assigns, :name, truncate(assigns.pax.singular_name, opts.truncate_length))

    ~H"""
    <.pax_button :if={@pax.new_path} navigate={@pax.new_path} level={:primary}>
      New {@name}
    </.pax_button>
    """
  end
end
