defmodule Pax.Plugins.Breadcrumbs do
  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  @default_placement [:show_header_primary, :edit_header_primary, :new_header_primary, :delete_header_primary]
  @default_truncate_length 25

  @impl true
  def init(_callback_module, opts) do
    %{
      placement: Keyword.get(opts, :placement, @default_placement),
      truncate_length: Keyword.get(opts, :truncate_length, @default_truncate_length)
    }
  end

  @impl true
  def config_key(), do: :breadcrumbs

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
    do: breadcrumbs(opts, assigns)

  def render(%{placement: placement} = opts, section, assigns) when is_list(placement) do
    if Enum.member?(placement, section) do
      breadcrumbs(opts, assigns)
    else
      nil
    end
  end

  def render(_opts, _section, _assigns), do: nil

  def breadcrumbs(opts, assigns) do
    assigns = assign(assigns, index_title: truncate(assigns.pax.plural_name, opts.truncate_length))

    ~H"""
    <div :if={@pax.index_path && @index_title} class="pax-breadcrumbs">
      <.pax_link class="pax-breadcrumbs-link" navigate={@pax.index_path}>
        {@index_title}
      </.pax_link>

      <span :if={@pax.object_name} class="pax-breadcrumbs-separator">/</span>
    </div>
    """
  end
end
