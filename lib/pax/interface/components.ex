defmodule Pax.Interface.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components

  attr :pax, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div class={["pax pax-index", @class]}>
      <.pax_header pax={@pax}>
        <:title>
          <%= @pax.plural_name %>
        </:title>

        <:action :if={@pax.new_path}>
          <.pax_button navigate={@pax.new_path}>New</.pax_button>
        </:action>
      </.pax_header>

      <.table fields={@pax.fields} objects={@objects}>
        <:header :let={field}>
          <.field_label field={field} />
        </:header>
        <:cell :let={{field, object}}>
          <.field_link_or_text field={field} object={object} />
        </:cell>
      </.table>
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :object, :map, required: true
  attr :class, :string, default: nil

  def show(assigns) do
    ~H"""
    <div class={["pax pax-detail pax-detail-show", @class]}>
      <.pax_header pax={@pax}>
        <:title>
          <%= @pax.object_name %>
        </:title>

        <:action :if={@pax.edit_path}>
          <.pax_button patch={@pax.edit_path}>Edit</.pax_button>
        </:action>
      </.pax_header>

      <%= for fieldset <- @pax.fieldsets do %>
        <.fieldset :let={fieldgroup} fieldset={fieldset}>
          <.fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
            <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
              <.field_label field={field} />
              <.field_text field={field} object={@object} />
            </div>
          </.fieldgroup>
        </.fieldset>
      <% end %>

      <div class="pax-button-group">
        <.pax_button :if={@pax.edit_path} patch={@pax.edit_path}>Edit</.pax_button>
        <.pax_button :if={@pax.index_path} navigate={@pax.index_path} secondary={true}>
          Back
        </.pax_button>
      </div>
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :object, :map, required: true
  attr :form, :any, required: true
  attr :class, :string, default: nil

  def new(assigns) do
    assigns
    |> assign(new: true)
    |> edit()
  end

  attr :pax, :map, required: true
  attr :object, :map, required: true
  attr :form, :any, required: true
  attr :class, :string, default: nil
  attr :new, :boolean, default: false

  def edit(assigns) do
    ~H"""
    <div class={["pax pax-detail pax-detail-edit", @class]}>
      <.form :let={f} for={@form} as={:detail} phx-change="pax_validate" phx-submit="pax_save">
        <.pax_header pax={@pax}>
          <:title :if={@new}>
            New <%= @pax.singular_name %>
          </:title>

          <:title :if={not @new}>
            Edit <%= @pax.object_name %>
          </:title>

          <:action :if={@pax.show_path}>
            <.pax_button patch={@pax.show_path} secondary={true}>Cancel</.pax_button>
          </:action>

          <:action>
            <.pax_button type="submit" phx-disable-with="Saving...">Save</.pax_button>
          </:action>
        </.pax_header>

        <%= for fieldset <- @pax.fieldsets do %>
          <.fieldset :let={fieldgroup} fieldset={fieldset}>
            <.fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
              <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
                <.field_label field={field} form={f} />
                <.field_input field={field} form={f} object={@object} />
              </div>
            </.fieldgroup>
          </.fieldset>
        <% end %>
        <div class="pax-button-group">
          <.pax_button type="submit" phx-disable-with="Saving..." name="detail[save]" value="save">
            Save
          </.pax_button>
          <.pax_button :if={@pax.show_path} patch={@pax.show_path} secondary={true}>
            Cancel
          </.pax_button>
          <.pax_button :if={@pax.index_path} navigate={@pax.index_path} secondary={true}>
            Back
          </.pax_button>
        </div>
      </.form>
    </div>
    """
  end

  attr :fields, :list, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  slot :header, required: true
  slot :cell, required: true

  def table(assigns) do
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

  def fieldset(assigns) do
    {name, fieldgroups} = assigns.fieldset
    assigns = assigns |> Map.put(:name, name) |> Map.put(:fieldgroups, fieldgroups)

    ~H"""
    <div class="pax-detail-fieldset">
      <div :if={@name != :default} class="pax-detail-fieldset-heading">
        <%= @name |> to_string() |> String.capitalize() %>
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

  def fieldgroup(assigns) do
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
