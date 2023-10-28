defmodule Pax.Admin.Resource.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components
  import Pax.Admin.Components

  attr :pax, :map, required: true
  attr :objects, :list, required: true
  attr :class, :string, default: nil

  def index(assigns) do
    ~H"""
    <div class={["", @class]}>
      <.header>
        <:title>
          <%= @pax.plural_name %>
        </:title>

        <:tool :if={@pax.new_path}>
          <.button navigate={@pax.new_path}>New</.button>
        </:tool>
      </.header>

      <.table fields={@pax.fields} objects={@objects}>
        <:header :let={field}>
          <.field_label field={field} />
        </:header>
        <:cell :let={{field, object}}>
          <.field_link_or_text link_class="font-bold underline" field={field} object={object} />
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
    <div class={["", @class]}>
      <.header>
        <:title>
          <%= @pax.object_name %>
        </:title>

        <:tool :if={@pax.edit_path}>
          <.button patch={@pax.edit_path}>Edit</.button>
        </:tool>
      </.header>

      <%= for fieldset <- @pax.fieldsets do %>
        <.fieldset :let={fieldgroup} fieldset={fieldset}>
          <.fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
            <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
              <.field_label class="font-bold" field={field} />
              <.field_text field={field} object={@object} />
            </div>
          </.fieldgroup>
        </.fieldset>
      <% end %>

      <div class="px-4 flex flex-wrap content-center items-center gap-2">
        <.button :if={@pax.edit_path} patch={@pax.edit_path}>Edit</.button>
        <.button :if={@pax.index_path} navigate={@pax.index_path} secondary={true}>
          Back
        </.button>
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
        <.header>
          <:title :if={@new}>
            New <%= @pax.singular_name %>
          </:title>

          <:title :if={not @new}>
            Edit <%= @pax.object_name %>
          </:title>

          <:tool :if={@pax.show_path}>
            <.pax_button patch={@pax.show_path} secondary={true}>Cancel</.pax_button>
          </:tool>

          <:tool>
            <.pax_button type="submit" phx-disable-with="Saving...">Save</.pax_button>
          </:tool>
        </.header>

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
    <div class="overflow-x-auto text-sm" role="region" aria-label="Index table" tabindex="0">
      <table class={["border-collapse w-full", @class]}>
        <thead>
          <tr>
            <%= for field <- @fields do %>
              <th class="py-[2px] px-2 first:pl-4 last:pr-4text-left align-bottom">
                <%= render_slot(@header, field) %>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody>
          <%= for object <- @objects do %>
            <tr>
              <%= for field <- @fields do %>
                <td class="py-[2px] px-2 first:pl-4 last:pr-4 align-top">
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
    <div class="mb-4">
      <div :if={@name != :default} class="text-xl border-b border-zinc-200 dark:border-zinc-750 py-2 px-4 mb-4">
        <%= @name |> to_string() |> String.capitalize() %>
      </div>
      <div class="px-4">
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
    <div class={["flex flex-col lg:flex-row lg:gap-8", "pax-fieldgroup-count-#{Enum.count(@fieldgroup)}"]}>
      <%= for field <- @fieldgroup do %>
        <%= render_slot(@inner_block, field) %>
      <% end %>
    </div>
    """
  end
end
