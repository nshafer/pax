defmodule Pax.Plugins.IndexTable do
  @moduledoc """
  Renders a table for the index view of a Pax.Interface.

  There are no options currently.
  """

  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Field.Components

  def render_component(_opts, :index_body, assigns) do
    ~H"""
    <.pax_index_table fields={@pax.fields} objects={@pax.objects}>
      <:header :let={field}>
        <.pax_field_label field={field} />
      </:header>
      <:cell :let={{field, object}}>
        <.pax_field_link_or_text field={field} object={object} />
      </:cell>
    </.pax_index_table>
    """
  end

  def render_component(_opts, _component, _assigns), do: nil

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
end
