defmodule Pax.Interface.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_index(assigns) do
    ~H"""
    <div class={["pax pax-index", @class]}>
      <.pax_header class="pax-index-header">
        <:primary>
          <.pax_title>
            <%= @pax.plural_name %>
          </.pax_title>

          <%= plugin_component(:index_header_primary, assigns) %>
        </:primary>

        <:secondary>
          <%= plugin_component(:index_header_secondary, assigns) %>
          <.pax_button :if={@pax.new_path} navigate={@pax.new_path}>New <%= @pax.singular_name %></.pax_button>
        </:secondary>

        <:tertiary>
          <%= plugin_component(:index_header_tertiary, assigns) %>
        </:tertiary>
      </.pax_header>

      <.pax_index_table fields={@pax.fields} objects={@pax.objects}>
        <:header :let={field}>
          <.pax_field_label field={field} />
        </:header>
        <:cell :let={{field, object}}>
          <.pax_field_link_or_text field={field} object={object} />
        </:cell>
      </.pax_index_table>

      <.pax_footer>
        <:primary>
          <%= plugin_component(:index_footer_primary, assigns) %>
        </:primary>

        <:secondary>
          <%= plugin_component(:index_footer_secondary, assigns) %>
        </:secondary>

        <:tertiary>
          <%= plugin_component(:index_footer_tertiary, assigns) %>
        </:tertiary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_show(assigns) do
    ~H"""
    <div class={["pax pax-detail pax-detail-show", @class]}>
      <.pax_header class="pax-detail-header pax-detail-show-header">
        <:primary>
          <div class="pax-title-breadcrumbs">
            <.pax_link :if={@pax.index_path} class="pax-detail-index-breadcrumb-link" navigate={@pax.index_path}>
              <%= @pax.plural_name %>
            </.pax_link>

            <span class="pax-detail-index-breadcrumb-separator">/</span>

            <.pax_title class="pax-detail-title">
              <%= @pax.object_name %>
            </.pax_title>
          </div>
        </:primary>

        <:secondary>
          <.pax_button :if={@pax.edit_path} class="pax-detail-edit-button" patch={@pax.edit_path}>Edit</.pax_button>
        </:secondary>
      </.pax_header>

      <div class="pax-detail-body">
        <%= for fieldset <- @pax.fieldsets do %>
          <.pax_fieldset :let={fieldgroup} fieldset={fieldset}>
            <.pax_fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
              <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
                <.pax_field_label field={field} />
                <.pax_field_text field={field} object={@pax.object} />
              </div>
            </.pax_fieldgroup>
          </.pax_fieldset>
        <% end %>
      </div>

      <.pax_footer>
        <:primary></:primary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_new(assigns) do
    assigns
    |> assign(new: true)
    |> pax_edit()
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil
  attr :new, :boolean, default: false

  def pax_edit(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@pax.form}
      as={:detail}
      class={["pax pax-detail pax-detail-edit", @class]}
      phx-change="pax_validate"
      phx-submit="pax_save"
    >
      <.pax_header class="pax-detail-header pax-detail-edit-header">
        <:primary>
          <div class="pax-title-breadcrumbs">
            <.pax_link :if={@pax.index_path} class="pax-detail-index-breadcrumb-link" navigate={@pax.index_path}>
              <%= @pax.plural_name %>
            </.pax_link>

            <span class="pax-detail-index-breadcrumb-separator">/</span>

            <.pax_title :if={@new}>
              New <%= @pax.singular_name %>
            </.pax_title>

            <.pax_title :if={not @new}>
              <%= @pax.object_name %>
            </.pax_title>
          </div>
        </:primary>

        <:secondary>
          <.pax_button :if={@pax.show_path} class="pax-detail-cancel-button" patch={@pax.show_path} secondary={true}>
            Cancel
          </.pax_button>

          <.pax_button
            class="pax-detail-save-button"
            type="submit"
            phx-disable-with="Saving..."
            name="detail[save]"
            value="save"
          >
            Save
          </.pax_button>
        </:secondary>
      </.pax_header>

      <div class="pax-detail-body">
        <%= for fieldset <- @pax.fieldsets do %>
          <.pax_fieldset :let={fieldgroup} fieldset={fieldset}>
            <.pax_fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
              <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
                <.pax_field_label field={field} form={f} />
                <.pax_field_input field={field} form={f} object={@pax.object} />
              </div>
            </.pax_fieldgroup>
          </.pax_fieldset>
        <% end %>
      </div>

      <.pax_footer>
        <:primary></:primary>
      </.pax_footer>
    </.form>
    """
  end

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  slot :header, required: true
  slot :cell, required: true

  def pax_index_table(assigns) do
    ~H"""
    <div class="pax-table-wrapper" role="region" aria-label="Index table" tabindex="0">
      <table class={["pax-index-table", @class]}>
        <thead class="pax-index-table-head">
          <tr class="pax-index-table-head-row">
            <%= for field <- @fields do %>
              <th class="pax-index-table-header">
                <%= render_slot(@header, field) %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr class="pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-index-table-datacell">
                  <%= render_slot(@cell, {field, object}) %>
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  attr :fieldset, :any, required: true
  slot :inner_block, required: true

  def pax_fieldset(assigns) do
    {name, fieldgroups} = assigns.fieldset
    assigns = assigns |> Map.put(:name, name) |> Map.put(:fieldgroups, fieldgroups)

    ~H"""
    <div class="pax-detail-fieldset">
      <div :if={@name != :default} class="pax-detail-fieldset-heading">
        <.pax_title level={2}>
          <%= @name |> to_string() |> String.capitalize() %>
        </.pax_title>
      </div>
      <div class="pax-detail-fieldset-body">
        <%= for fieldgroup <- @fieldgroups do %>
          <%= render_slot(@inner_block, fieldgroup) %>
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
        <%= render_slot(@inner_block, field) %>
      <% end %>
    </div>
    """
  end
end
