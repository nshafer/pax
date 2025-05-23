defmodule Pax.Plugins.DetailList do
  @moduledoc """
  Renders a list of fields for the detail view of a Pax.Interface. The display is of a simple two column list, with the
  field name on the left and the field value on the right.

  ## Options:
  - `:placement` - A list of sections where the detail list should be rendered. The default is
    `[:show_body, :edit_body, :new_body]`.
  - `:fields` - A list of field names (as atoms) to include in the list and the order to include them.
    If not provided, all fields will be displayed in their original order. If any field name in the list
    is not available in the fields for that action, that field will be skipped. Field names must be atoms.
  """

  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Field.Components

  @default_placement [:show_body, :edit_body, :new_body]

  @impl true
  def init(_callback_module, opts) do
    %{
      placement: Keyword.get(opts, :placement, @default_placement)
    }
  end

  @impl true
  def config_key(), do: :detail_list

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
    do: detail_list(opts, assigns)

  def render(%{placement: placement} = opts, section, assigns) do
    if Enum.member?(placement, section) do
      detail_list(opts, assigns)
    else
      nil
    end
  end

  def render(_opts, _section, _assigns), do: nil

  defp detail_list(opts, assigns) do
    assigns = assign(assigns, :fields, init_fields(opts.field_list, assigns.pax.fields))

    ~H"""
    <%= for field <- @fields do %>
      <.detail_list_item>
        <:label>
          <.pax_field_label class="pax-detail-list-field-label" field={field} form={@pax.form} />
        </:label>
        <:body>
          <.pax_field_input_or_text
            input_class="pax-detail-list-field-input"
            text_class="pax-detail-list-field-text"
            field={field}
            form={@pax.form}
            object={@pax.object}
          />
        </:body>
      </.detail_list_item>
    <% end %>
    """
  end

  slot :label, required: true
  slot :body, required: true

  defp detail_list_item(assigns) do
    ~H"""
    <div class="pax-detail-list-item">
      <div class="pax-detail-list-item-label">
        {render_slot(@label)}
      </div>
      <div class="pax-detail-list-item-body">
        {render_slot(@body)}
      </div>
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
