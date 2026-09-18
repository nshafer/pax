defmodule Pax.Plugins.Title do
  @opts_schema NimbleOptions.new!(
                 placement: [
                   type: {:or, [:atom, {:list, :atom}]},
                   default: [
                     :index_header_primary,
                     :show_header_primary,
                     :edit_header_primary,
                     :new_header_primary,
                     :delete_header_primary
                   ],
                   doc: "The section, or list of sections, to render the title in."
                 ],
                 truncate_length: [
                   type: :pos_integer,
                   default: 50,
                   doc: "The length to truncate the title to."
                 ]
               )

  @moduledoc """
  Renders the title of each page of a Pax.Interface.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}
  """

  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Util.String

  @impl true
  def init(_callback_module, opts) do
    opts
    |> Pax.Options.validate!(@opts_schema, "plugin #{inspect(__MODULE__)}")
    |> Map.new()
  end

  @impl true
  def config_key(), do: :title

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
    do: title(opts, assigns)

  def render(%{placement: placement} = opts, section, assigns) when is_list(placement) do
    if Enum.member?(placement, section) do
      title(opts, assigns)
    else
      nil
    end
  end

  def render(_opts, _section, _assigns), do: nil

  def title(opts, %{pax: %{action: :index}} = assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.plural_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-index-title">
      {@title}
    </.pax_title>
    """
  end

  def title(opts, %{pax: %{action: :show}} = assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-show-title">
      {@title}
    </.pax_title>
    """
  end

  def title(opts, %{pax: %{action: :edit}} = assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-edit-title">
      Edit: {@title}
    </.pax_title>
    """
  end

  def title(opts, %{pax: %{action: :new}} = assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.singular_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-new-title">
      New {@title}
    </.pax_title>
    """
  end

  def title(opts, %{pax: %{action: :delete}} = assigns) do
    assigns = assign(assigns, :title, truncate(assigns.pax.object_name, opts.truncate_length))

    ~H"""
    <.pax_title class="pax-detail-title pax-delete-title">
      Delete: {@title}
    </.pax_title>
    """
  end

  def title(_opts, _assigns), do: nil
end
