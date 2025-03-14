defmodule Pax.Interface.Components do
  use Phoenix.Component
  import Pax.Components
  import Pax.Field.Components
  import Pax.Util.String

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil
  attr :index_class, :string, default: nil
  attr :show_class, :string, default: nil
  attr :new_class, :string, default: nil
  attr :edit_class, :string, default: nil

  def pax_interface(assigns) do
    ~H"""
    <div :if={assigns[:pax]} class="pax-interface">
      {pax_interface_action(assigns)}
    </div>
    """
  end

  def pax_interface_action(assigns) do
    case assigns.pax.action do
      :index -> assigns |> Map.put(:class, assigns.index_class) |> pax_index()
      :show -> assigns |> Map.put(:class, assigns.show_class) |> pax_show()
      :new -> assigns |> Map.put(:class, assigns.new_class) |> pax_new()
      :edit -> assigns |> Map.put(:class, assigns.edit_class) |> pax_edit()
      _ -> nil
    end
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_index(assigns) do
    ~H"""
    <div class={["pax-index", @class]}>
      <.pax_header class="pax-index-header">
        <:primary>
          {pax_plugin_component(:index_header_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:index_header_secondary, assigns)}
          <.pax_button :if={@pax.new_path} navigate={@pax.new_path}>New {truncate(@pax.singular_name, 25)}</.pax_button>
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:index_header_tertiary, assigns)}
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

      <.pax_footer class="pax-index-footer">
        <:primary>
          {pax_plugin_component(:index_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:index_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:index_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_show(assigns) do
    ~H"""
    <div class={["pax-detail pax-detail-show", @class]}>
      <.pax_header class="pax-detail-header pax-detail-show-header">
        <:primary>
          {pax_plugin_component(:show_header_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:show_header_secondary, assigns)}
          <.pax_button :if={@pax.edit_path} class="pax-detail-edit-button" patch={@pax.edit_path}>Edit</.pax_button>
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:show_header_tertiary, assigns)}
        </:tertiary>
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

      <.pax_footer class="pax-detail-footer pax-detail-show-footer">
        <:primary>
          {pax_plugin_component(:show_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:show_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:show_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </div>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_edit(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@pax.form}
      as={:detail}
      class={["pax-detail pax-detail-edit", @class]}
      phx-change="pax_validate"
      phx-submit="pax_save"
    >
      <.pax_header class="pax-detail-header pax-detail-edit-header">
        <:primary>
          {pax_plugin_component(:edit_header_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:edit_header_secondary, assigns)}
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
        <:tertiary>
          {pax_plugin_component(:edit_header_tertiary, assigns)}
        </:tertiary>
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

      <.pax_footer class="pax-detail-footer pax-detail-edit-footer">
        <:primary>
          {pax_plugin_component(:edit_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:edit_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:edit_footer_tertiary, assigns)}
        </:tertiary>
      </.pax_footer>
    </.form>
    """
  end

  attr :pax, Pax.Interface.Context, required: true
  attr :class, :string, default: nil

  def pax_new(assigns) do
    ~H"""
    <.form
      :let={f}
      for={@pax.form}
      as={:detail}
      class={["pax-detail pax-detail-new", @class]}
      phx-change="pax_validate"
      phx-submit="pax_save"
    >
      <.pax_header class="pax-detail-header pax-detail-new-header">
        <:primary>
          {pax_plugin_component(:new_header_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:new_header_secondary, assigns)}
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
        <:tertiary>
          {pax_plugin_component(:new_header_tertiary, assigns)}
        </:tertiary>
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

      <.pax_footer class="pax-detail-footer pax-detail-new-footer">
        <:primary>
          {pax_plugin_component(:new_footer_primary, assigns)}
        </:primary>

        <:secondary>
          {pax_plugin_component(:new_footer_secondary, assigns)}
        </:secondary>

        <:tertiary>
          {pax_plugin_component(:new_footer_tertiary, assigns)}
        </:tertiary>
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
                {render_slot(@header, field)}
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody id="pax-objects" phx-update="stream">
          <%= for {dom_id, object} <- @objects do %>
            <tr id={dom_id} class="pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-index-table-datacell">
                  {render_slot(@cell, {field, object})}
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
