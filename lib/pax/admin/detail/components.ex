defmodule Pax.Admin.Detail.Components do
  use Phoenix.Component

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr(:object, :map, required: true)
  attr(:class, :string, default: nil)

  def detail(assigns) do
    ~H"""
    <div class={["pax-detail", @class]}>
      <%= for {name, fields} <- @pax.fieldsets do %>
        <Pax.Admin.Detail.Components.fieldset pax={@pax} resource={@resource} name={name} fields={fields} object={@object} />
      <% end %>
    </div>
    """
  end

  attr :pax, :map, required: true
  attr :resource, :map, required: true
  attr :name, :string, required: true
  attr :fields, :list, required: true
  attr :object, :map, required: true

  def fieldset(assigns) do
    ~H"""
    <div class="pax-detail-fieldset">
      <div :if={@name != :default} class="pax-detail-fieldset-heading">
        <%= @name |> to_string() |> String.capitalize() %>
      </div>
      <div class="pax-detail-fieldset-body">
        <%= for row <- @fields do %>
          <div class={["pax-detail-fieldset-row", "pax-field-count-#{Enum.count(row)}"]}>
            <%= for {field, i} <- Enum.with_index(row) do %>
              <div class={["pax-detail-field", "pax-detail-field-#{i}"]}>
                <div class="pax-detail-field-title">
                  <Pax.Field.Components.title field={field} />
                </div>
                <div class="pax-detail-field-text">
                  <Pax.Field.Components.display_as_text field={field} object={@object} />
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
