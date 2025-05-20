defmodule Pax.Plugins.DetailFieldsets do
  @moduledoc """
  Renders fieldsets for the detail view of a Pax.Interface. Fieldsets are a way to organize a detail page, by breaking
  it into sections, and allowing fields to be grouped together on the same horizontal line.

  There is a default fieldset called `:default` that is used when no fieldset is specified. The default fieldset is
  rendered at the top of the page with no header. All other fieldsets will be rendered with a header above their
  fields.

  ## Options:
  - `:placement` - A list of sections where the fieldsets should be rendered. The default is
    `[:show_body, :edit_body, :new_body]`.
  - `:fieldsets` - A structure defining the fieldsets, fieldgroups, and their contained fields. This determines which
    fields to include, their organization, and the order to display them. The structure should be a list of tuples of
    the form `{name, fieldgroups}` where `name` is an atom or string and `fieldgroups` is a list of fieldgroups.

    Each fieldgroup can be either:
    - A list of field names (as atoms), which will be displayed together horizontally
    - A single field name (as atom), which will be displayed on its own

    If a field name is included that isn't available in the fields for that action, it will be skipped. If this option
    is not provided, all fields will be placed in the `:default` fieldset, with each field in its own fieldgroup.

    Example:
    ```
    [
      default: [:name, :email],
      details: [
        [:address, :city],
        :phone,
        [:created_at, :updated_at]
      ]
    ]
    ```
  """

  use Phoenix.Component
  use Pax.Interface.Plugin
  import Pax.Field.Components
  import Pax.Components

  @default_placement [:show_body, :edit_body, :new_body]

  @impl true
  def init(_callback_module, opts) do
    %{
      placement: Keyword.get(opts, :placement, @default_placement)
    }
  end

  @impl true
  def config_key(), do: :detail_fieldsets

  @impl true
  def config_spec() do
    %{
      placement: [:list, {:function, 1, :list}],
      fieldsets: [:list, {:function, 1, :list}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      placement: Pax.Config.get(config, :placement, [socket], opts.placement),
      fieldsets: Pax.Config.get(config, :fieldsets, [socket], nil)
    }
  end

  @impl true
  def render_component(%{placement: placement, fieldsets: fieldsets}, section, assigns) do
    if Enum.member?(placement, section) do
      fieldsets = init_fieldsets(fieldsets, assigns.pax.fields)

      assigns
      |> assign(:fieldsets, fieldsets)
      |> detail_fieldsets()
    else
      nil
    end
  end

  def render_component(_opts, _section, _assigns), do: nil

  defp detail_fieldsets(assigns) do
    ~H"""
    <div class="pax-detail-fieldsets">
      <%= for fieldset <- @fieldsets do %>
        <.pax_fieldset :let={fieldgroup} fieldset={fieldset}>
          <.pax_fieldgroup :let={{field, i}} fieldgroup={fieldgroup} with_index={true}>
            <div class={["pax-detail-fieldsets-field", "pax-detail-fieldsets-field-#{i}"]}>
              <.pax_field_label class="pax-detail-fieldsets-field-label" field={field} form={@pax.form} />
              <.pax_field_input_or_text
                input_class="pax-detail-fieldsets-field-input"
                text_class="pax-detail-fieldsets-field-text"
                field={field}
                form={@pax.form}
                object={@pax.object}
              />
            </div>
          </.pax_fieldgroup>
        </.pax_fieldset>
      <% end %>
    </div>
    """
  end

  attr :fieldset, :any, required: true
  slot :inner_block, required: true

  defp pax_fieldset(assigns) do
    {name, fieldgroups} = assigns.fieldset
    assigns = assigns |> Map.put(:name, name) |> Map.put(:fieldgroups, fieldgroups)

    ~H"""
    <div class="pax-detail-fieldsets-fieldset">
      <div :if={@name != :default} class="pax-detail-fieldsets-fieldset-heading">
        <.pax_title level={2}>
          {titleize(@name)}
        </.pax_title>
      </div>
      <div class="pax-detail-fieldsets-fieldset-body">
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

  defp pax_fieldgroup(assigns) do
    fields = if assigns.with_index, do: Enum.with_index(assigns.fieldgroup), else: assigns.fieldgroup
    assigns = Map.put(assigns, :fieldgroup, fields)

    ~H"""
    <div class={["pax-detail-fieldsets-fieldgroup", "pax-detail-fieldsets-fieldgroup-count-#{Enum.count(@fieldgroup)}"]}>
      <%= for field <- @fieldgroup do %>
        {render_slot(@inner_block, field)}
      <% end %>
    </div>
    """
  end

  defp titleize(name) when is_atom(name) do
    name
    |> to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
    |> Pax.Util.String.truncate(50)
  end

  defp titleize(name) when is_binary(name) do
    Pax.Util.String.truncate(name, 50)
  end

  # If no fieldsets are provided, we'll render the default fieldset with a list of fieldgroups with a single field.
  defp init_fieldsets(nil, fields) do
    fieldgroups = Enum.map(fields, fn field -> [field] end)
    [default: fieldgroups]
  end

  # If the fieldsets are provided, which should be a structure of fieldsets and fieldgroups, but with just the
  # name of the field where it should go, then we'll transform that into the final fieldsets with a copy of the
  # fields in the proper place for rendering. If a field is given that is not in the list of fields, we'll
  # ignore it and not render it.
  defp init_fieldsets(fieldsets, fields) do
    # First create a map of field names to their fields for quick lookup
    field_map = Map.new(fields, fn field -> {field.name, field} end)

    # Now initialize each fieldset
    Enum.map(fieldsets, &init_fieldset(&1, field_map))
  end

  defp init_fieldset({name, fieldgroups}, field_map) when (is_atom(name) or is_binary(name)) and is_list(fieldgroups) do
    fieldgroups =
      fieldgroups
      |> Enum.map(&init_fieldgroup(&1, field_map))
      |> Enum.reject(&is_nil/1)

    {name, fieldgroups}
  end

  defp init_fieldset(val, _field_map) do
    raise """
    Invalid fieldset:

    #{inspect(val)}

    Fieldsets must be a tuple of the form {name, fieldgroups}
    where name is an atom or string and fieldgroups is a list of fieldgroups.
    """
  end

  defp init_fieldgroup(fieldgroup, field_map) when is_list(fieldgroup) do
    fieldgroup
    |> Enum.map(fn field_name -> init_field(field_name, field_map) end)
    |> Enum.reject(&is_nil/1)
  end

  defp init_fieldgroup(field_name, field_map) when is_atom(field_name) do
    case init_field(field_name, field_map) do
      nil -> nil
      field -> [field]
    end
  end

  defp init_fieldgroup(val, _field_map) do
    raise """
    Invalid fieldgroup:

    #{inspect(val)}

    Fieldgroups must be a list of field names or a single field name. Field names must be atoms.
    """
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

    Field names must be atoms, and must be in the list of fields.
    """
  end
end
