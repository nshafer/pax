defmodule Pax.Plugins.DetailFieldsets do
  @moduledoc """
  Renders fieldsets for the detail view of a Pax.Interface. Fieldsets are a way to organize a detail page, by breaking
  it into sections, and allowing fields to be grouped together on the same horizontal line.

  There is a default fieldset called `:default` that is used when no fieldset is specified. The default fieldset is
  rendered at the top of the page with no header. All other fieldsets will be rendered with a header above their
  fields.

  TODO: Make this plugin use its own config for arranging the fieldsets, once the `fieldsets` config is removed in
        favor of just specifying one list of `fields`.

  ## Options:
  - `:placement` - A list of sections where the fieldsets should be rendered. The default is
    `[:show_body, :edit_body, :new_body]`.
  """

  use Phoenix.Component
  use Pax.Interface.Plugin
  import Pax.Field.Components
  import Pax.Components
  import Pax.Util.String

  @default_placement [:show_body, :edit_body, :new_body]

  @impl true
  def init(_callback_module, opts) do
    %{
      placement: Keyword.get(opts, :placement, @default_placement)
    }
  end

  @impl true
  def config_key(), do: :detail_fieldsets

  @impl true
  def config_spec() do
    %{
      placement: [:list, {:function, 1, :list}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      placement: Pax.Config.get(config, :placement, [socket], opts.placement)
    }
  end

  @impl true
  def render_component(%{placement: placement}, section, assigns) do
    if Enum.member?(placement, section) do
      detail_fieldsets(assigns)
    else
      nil
    end
  end

  def render_component(_opts, _section, _assigns), do: nil

  defp detail_fieldsets(assigns) do
    ~H"""
    <%= for fieldset <- @pax.fieldsets do %>
      <.pax_fieldset :let={fieldgroup} fieldset={fieldset}>
        <.pax_fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
          <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
            <.pax_field_label field={field} form={@pax.form} />
            <.pax_field_input_or_text field={field} form={@pax.form} object={@pax.object} />
          </div>
        </.pax_fieldgroup>
      </.pax_fieldset>
    <% end %>
    """
  end

  # Moved from Pax.Interface.Components
  attr :fieldset, :any, required: true
  slot :inner_block, required: true

  def pax_fieldset(assigns) do
    {name, fieldgroups} = assigns.fieldset
    assigns = assigns |> Map.put(:name, name) |> Map.put(:fieldgroups, fieldgroups)

    ~H"""
    <div class="pax-detail-fieldset">
      <div :if={@name != :default} class="pax-detail-fieldset-heading">
        <.pax_title level={2}>
          {@name |> to_string() |> String.capitalize() |> truncate(50)}
        </.pax_title>
      </div>
      <div class="pax-detail-fieldset-body">
        <%= for fieldgroup <- @fieldgroups do %>
          {render_slot(@inner_block, fieldgroup)}
        <% end %>
      </div>
    </div>
    """
  end

  attr :fieldgroup, :any, required: true
  attr :with_index, :boolean, default: false
  slot :inner_block, required: true

  def pax_fieldgroup(assigns) do
    fields = if assigns.with_index, do: Enum.with_index(assigns.fieldgroup), else: assigns.fieldgroup
    assigns = Map.put(assigns, :fieldgroup, fields)

    ~H"""
    <div class={["pax-detail-fieldgroup", "pax-fieldgroup-count-#{Enum.count(@fieldgroup)}"]}>
      <%= for field <- @fieldgroup do %>
        {render_slot(@inner_block, field)}
      <% end %>
    </div>
    """
  end
end
