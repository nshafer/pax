defmodule Pax.Plugins.Title do
  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  @default_truncate_length 50
  @default_index_placement :index_header_primary
  @default_show_placement :show_header_primary
  @default_edit_placement :edit_header_primary
  @default_new_placement :new_header_primary
  @default_delete_placement :delete_header_primary

  @impl true
  def init(_callback_module, opts) do
    %{
      truncate_length: Keyword.get(opts, :truncate_length, @default_truncate_length),
      index_placement: Keyword.get(opts, :index_placement, @default_index_placement),
      show_placement: Keyword.get(opts, :show_placement, @default_show_placement),
      edit_placement: Keyword.get(opts, :edit_placement, @default_edit_placement),
      new_placement: Keyword.get(opts, :new_placement, @default_new_placement),
      delete_placement: Keyword.get(opts, :delete_placement, @default_delete_placement)
    }
  end

  @impl true
  def config_key(), do: :title

  @impl true
  def config_spec() do
    %{
      truncate_length: [:integer, {:function, 1, :integer}],
      index_placement: [:atom, {:function, 1, :atom}],
      show_placement: [:atom, {:function, 1, :atom}],
      edit_placement: [:atom, {:function, 1, :atom}],
      new_placement: [:atom, {:function, 1, :atom}],
      delete_placement: [:atom, {:function, 1, :atom}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      truncate_length: Pax.Config.get(config, :truncate_length, [socket], opts.truncate_length),
      index_placement: Pax.Config.get(config, :index_placement, [socket], opts.index_placement),
      show_placement: Pax.Config.get(config, :show_placement, [socket], opts.show_placement),
      edit_placement: Pax.Config.get(config, :edit_placement, [socket], opts.edit_placement),
      new_placement: Pax.Config.get(config, :new_placement, [socket], opts.new_placement),
      delete_placement: Pax.Config.get(config, :delete_placement, [socket], opts.delete_placement)
    }
  end

  @impl true
  def render_component(%{index_placement: index_placement} = opts, index_placement, assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.plural_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-index-title">
      {@title}
    </.pax_title>
    """
  end

  def render_component(%{show_placement: show_placement} = opts, show_placement, assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-show-title">
      {@title}
    </.pax_title>
    """
  end

  def render_component(%{edit_placement: edit_placement} = opts, edit_placement, assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-edit-title">
      Edit: {@title}
    </.pax_title>
    """
  end

  def render_component(%{new_placement: new_placement} = opts, new_placement, assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.singular_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-new-title">
      New {@title}
    </.pax_title>
    """
  end

  def render_component(%{delete_placement: delete_placement} = opts, delete_placement, assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-delete-title">
      Delete: {@title}
    </.pax_title>
    """
  end

  def render_component(_opts, _component, _assigns), do: nil
end
