defmodule Pax.Plugins.IndexTable do
  @moduledoc """
  Renders a table for the index view of a Pax.Interface.

  ## Options:
  - `:placement` - The section to render the index table to. Default: `:index_body`.
  - `:fields` - A list of field names (as atoms) to include in the table and the order to include them.
    If not provided, all fields will be displayed in their original order. If any field name in the list
    is not available in the fields for that action, that field will be skipped. Field names must be atoms.
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
      placement: [:atom, :list, {:function, 1, [:atom, :list]}],
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
  def render(%{placement: placement} = opts, placement, assigns),
    do: index_table(opts, assigns)

  def render(%{placement: placement} = opts, section, assigns) when is_list(placement) do
    if Enum.member?(placement, section) do
      index_table(opts, assigns)
    else
      nil
    end
  end

  @impl true
  def render(_opts, _section, _assigns), do: nil

  def index_table(opts, assigns) do
    assigns = assign(assigns, :fields, init_fields(opts.field_list, assigns.pax.fields))

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
end
