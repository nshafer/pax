defmodule Pax.Plugins.IndexTable do
  @moduledoc """
  Renders a table for the index view of a Pax.Interface.

  There are no options currently.
  """

  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Field.Components

  @default_placement :index_body

  @impl true
  def init(_callback_module, opts) do
    %{placement: Keyword.get(opts, :placement, @default_placement)}
  end

  @impl true
  def config_key(), do: :index_table

  @impl true
  def config_spec() do
    %{
      placement: [:atom, {:function, 1, :atom}],
      fields: [:list, {:function, 1, :list}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      placement: Pax.Config.get(config, :placement, [socket], opts.placement),
      field_list: Pax.Config.get(config, :fields, [socket], nil)
    }
  end

  @impl true
  def render_component(%{placement: placement, field_list: field_list}, placement, assigns) do
    fields = init_fields(field_list, assigns.pax.fields)

    assigns
    |> assign(:fields, fields)
    |> index_table()
  end

  @impl true
  def render_component(_opts, _section, _assigns), do: nil

  # If no fields are provided, we will just render all fields in the same order as in the main `:fields` list.
  defp init_fields(nil, fields) do
    fields
  end

  # If given a list of field names to render, we will render only the given fields in the order they are provided.
  defp init_fields(field_list, fields) do
    # First create a map of field names to their fields for quick lookup
    field_map = Map.new(fields, fn field -> {field.name, field} end)

    # Now initialize all fields
    field_list
    |> Enum.map(&init_field(&1, field_map))
    |> Enum.reject(&is_nil/1)
  end

  defp init_field(field_name, field_map) when is_atom(field_name) do
    case Map.fetch(field_map, field_name) do
      {:ok, field} -> field
      :error -> nil
    end
  end

  defp init_field(val, _field_map) do
    raise """
    Invalid field:

    #{inspect(val)}

    Field name must be an atom.
    """
  end

  def index_table(assigns) do
    ~H"""
    <div class="pax-table-wrapper pax-index-table-wrapper" role="region" aria-label="Index table" tabindex="0">
      <table class="pax-table pax-index-table">
        <thead class="pax-table-head pax-index-table-head">
          <tr class="pax-table-head-row pax-index-table-head-row">
            <%= for field <- @fields do %>
              <th class="pax-table-header pax-index-table-header">
                <.pax_field_label field={field} />
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody id="pax-index-table-objects" class="pax-table-body pax-index-table-body" phx-update="stream">
          <%= for {dom_id, object} <- @pax.objects do %>
            <tr id={dom_id} class="pax-table-row pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-table-datacell pax-index-table-datacell">
                  <.pax_field_link_or_text field={field} object={object} />
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
