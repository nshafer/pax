defmodule Pax.Admin.Resource.Components do
  use Phoenix.Component
  import Pax.Interface.Components, only: [table: 1, fieldset: 1, fieldgroup: 1]
  import Pax.Components
  import Pax.Field.Components

  attr :pax, :map, required: true
  attr :resource, :map, required: true
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
          <.pax_button patch={@pax.new_path}>New</.pax_button>
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
        <.pax_button :if={@pax.index_path} patch={@pax.index_path} secondary={true}>
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

  def edit(assigns) do
    ~H"""
    <div class={["pax pax-detail pax-detail-edit", @class]}>
      <.form :let={f} for={@form} as={:detail} phx-change="pax_validate" phx-submit="pax_save">
        <.pax_header pax={@pax}>
          <:title>
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
          <.pax_button :if={@pax.index_path} patch={@pax.index_path} secondary={true}>
            Back
          </.pax_button>
        </div>
      </.form>
    </div>
    """
  end
end
