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
  import Pax.Interface
  import Pax.Components
  import Pax.Field.Components
  import Pax.Util.URI
  require Logger

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
  def handle_params(_opts, params, _uri, socket) do
    # IO.puts("[Pax.Plugins.IndexTable] handle_params(#{inspect(params)})")
    socket =
      socket
      |> assign_pax_private(:index_table, :default_sort_params, default_sort_params(socket))
      |> maybe_assign_sort_criteria(params)

    {:cont, socket}
  end

  defp maybe_assign_sort_criteria(socket, params) do
    # TODO: support multiple sorts in params
    with {:ok, order_by} <- get_sort(params, socket) do
      assign_pax_criteria(socket, order_by: order_by)
    else
      :not_found ->
        socket

      {:error, reason} ->
        Logger.info("[Pax.Plugins.IndexTable] ignoring invalid sort parameter: #{inspect(reason)}")
        socket
    end
  end

  defp get_sort(%{"sort" => sort_str}, socket) when is_binary(sort_str) do
    with {:ok, order_by} <- parse_sort(sort_str, socket) do
      {:ok, [order_by]}
    end
  end

  defp get_sort(%{"sort" => sort_list}, socket) when is_list(sort_list) do
    sort_list
    |> Enum.map(fn sort_str ->
      case parse_sort(sort_str, socket) do
        {:ok, order_by} ->
          order_by

        {:error, reason} ->
          Logger.info("[Pax.Plugins.IndexTable] ignoring invalid sort parameter: #{reason}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> then(fn
      [] -> :not_found
      order_by -> {:ok, order_by}
    end)
  end

  defp get_sort(_params, _socket), do: :not_found

  defp parse_sort(sort_str, socket) do
    with(
      {direction, field_str} <- parse_sort_str(sort_str),
      {:ok, field} <- parse_field(field_str),
      {:ok, field} <- validate_field(field, socket)
    ) do
      {:ok, {direction, field}}
    end
  end

  defp parse_sort_str(sort_str) do
    case sort_str do
      "-~" <> field_str -> {:desc_nulls_first, field_str}
      "-." <> field_str -> {:desc_nulls_last, field_str}
      "-" <> field_str -> {:desc, field_str}
      "~" <> field_str -> {:asc_nulls_first, field_str}
      "." <> field_str -> {:asc_nulls_last, field_str}
      field_str -> {:asc, field_str}
    end
  end

  defp parse_field(field_str) do
    {:ok, String.to_existing_atom(field_str)}
  rescue
    ArgumentError ->
      {:error, "field name '#{field_str}' is invalid or does not exist"}
  end

  defp validate_field(field, socket) do
    %{fields: fields} = socket.assigns.pax

    if Enum.any?(fields, fn
         %Pax.Field{opts: %{sort: ^field}} -> true
         _ -> false
       end) do
      {:ok, field}
    else
      {:error, "field '#{field}' is not sortable"}
    end
  end

  @impl true
  def after_params(_opts, socket) do
    with {:ok, sorts} <- get_sorts(socket.assigns.pax.criteria) do
      # Logger.warning("[IndexTable] sorts #{inspect(sorts)}")
      {:cont, assign_pax_private(socket, :index_table, :sorts, sorts)}
    else
      :not_found ->
        {:cont, assign_pax_private(socket, :index_table, :sorts, %{})}

      {:warning, reason} ->
        Logger.warning("[IndexTable] Warning: #{inspect(reason)}")
        {:cont, assign_pax_private(socket, :index_table, :sorts, %{})}
    end
  end

  defp get_sorts(%{order_by: field}) when is_atom(field) do
    {:ok, %{field => {1, :asc}}}
  end

  defp get_sorts(%{order_by: order_by}) when is_list(order_by) do
    {_, sorts} =
      for entry <- order_by, reduce: {1, %{}} do
        {sort_num, sorts} ->
          case entry do
            field when is_atom(field) ->
              {sort_num + 1, Map.put_new(sorts, field, {sort_num, :asc})}

            {direction, field} when is_atom(direction) and is_atom(field) ->
              {sort_num + 1, Map.put_new(sorts, field, {sort_num, direction})}

            entry ->
              throw(entry)
          end
      end

    {:ok, sorts}
  catch
    entry ->
      {:warning, "unexpected entry in order_by: #{inspect(entry)}, expected atom or tuple of `{direction, field}`"}
  end

  defp get_sorts(%{order_by: order_by}), do: {:warning, "order_by in criteria is unsupported: #{inspect(order_by)}"}

  defp get_sorts(_criteria), do: :not_found

  @impl true
  def render(%{placement: placement} = opts, placement, %{pax: %{action: :index}} = assigns),
    do: index_table(opts, assigns)

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
                <div class="pax-table-header-content pax-index-table-header-content">
                  <%= if sortable?(field) do %>
                    <.pax_link class="pax-index-table-header-link" patch={sort_link(field, @pax)}>
                      {Pax.Field.label(field)}
                    </.pax_link>
                  <% else %>
                    <div class="pax-index-table-header-label">
                      {Pax.Field.label(field)}
                    </div>
                  <% end %>
                  <div
                    :if={field_sorted?(field, @pax)}
                    class={[
                      "pax-index-table-header-sort",
                      "pax-index-table-header-sort-#{sort_direction(field, @pax)}",
                      "pax-index-table-header-sort-#{sort_num(field, @pax)}"
                    ]}
                  >
                    <.sort_indicator direction={sort_direction(field, @pax)} />
                    <.sort_number :if={num_sorts(@pax) > 1} num={sort_num(field, @pax)} />
                  </div>
                </div>
              </th>
            <% end %>
          </tr>
        </thead>
        <tbody id="pax-index-table-objects" class="pax-table-body pax-index-table-body" phx-update="stream">
          <%= for {dom_id, object} <- @pax.objects do %>
            <tr id={dom_id} class="pax-table-row pax-index-table-row">
              <%= for field <- @fields do %>
                <td class="pax-table-datacell pax-index-table-datacell">
                  <.pax_field_link_or_text
                    link_class="pax-table-datacell-link pax-index-table-datacell-link"
                    text_class="pax-table-datacell-text pax-index-table-datacell-text"
                    field={field}
                    object={object}
                    local_params={[index_query: encode_query_string(@pax.path.query)]}
                  />
                </td>
              <% end %>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # TODO: Could get the sort icon type from the field, fall back to field type: `A->Z`, `1->9`, size one, or just arrow.
  #       https://fontawesome.com/search?q=sort&o=r&ic=free&s=solid&ip=classic
  defp sort_indicator(%{direction: direction} = assigns) when direction in [:asc, :asc_nulls_first, :asc_nulls_last] do
    ~H"""
    <span class="pax-index-table-sort-icon" title={sort_icon_title(@direction)}>
      <.sort_asc_icon />
    </span>
    """
  end

  defp sort_indicator(%{direction: direction} = assigns)
       when direction in [:desc, :desc_nulls_first, :desc_nulls_last] do
    ~H"""
    <span class="pax-index-table-sort-icon" title={sort_icon_title(@direction)}>
      <.sort_desc_icon />
    </span>
    """
  end

  defp sort_indicator(assigns) do
    ~H"""
    <span class="pax-index-table-sort-icon" title={sort_icon_title(@direction)}>
      <.sort_icon />
    </span>
    """
  end

  defp sort_icon_title(:asc), do: "Ascending"
  defp sort_icon_title(:asc_nulls_first), do: "Ascending (nulls first)"
  defp sort_icon_title(:asc_nulls_last), do: "Ascending (nulls last)"
  defp sort_icon_title(:desc), do: "Descending"
  defp sort_icon_title(:desc_nulls_first), do: "Descending (nulls first)"
  defp sort_icon_title(:desc_nulls_last), do: "Descending (nulls last)"
  defp sort_icon_title(nil), do: "Not sorted"
  defp sort_icon_title(sort), do: to_string(sort)

  defp sort_number(assigns) do
    ~H"""
    <span :if={@num != nil} class="pax-index-table-sort-num" title={"Sort number: #{@num}"}>
      {if @num, do: @num, else: ""}
    </span>
    """
  end

  # https://fontawesome.com/icons/caret-up?f=classic&s=solid
  defp sort_asc_icon(assigns) do
    ~H"""
    <svg
      class="pax-icon pax-index-table-sort-icon"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 320 512"
      height="1em"
      width="1em"
    >
      <!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.-->
      <path d="M182.6 137.4c-12.5-12.5-32.8-12.5-45.3 0l-128 128c-9.2 9.2-11.9 22.9-6.9 34.9s16.6 19.8 29.6 19.8l256 0c12.9 0 24.6-7.8 29.6-19.8s2.2-25.7-6.9-34.9l-128-128z" />
    </svg>
    """
  end

  # https://fontawesome.com/icons/caret-down?f=classic&s=solid
  defp sort_desc_icon(assigns) do
    ~H"""
    <svg
      class="pax-icon pax-index-table-sort-icon"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 320 512"
      height="1em"
      width="1em"
    >
      <!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.-->
      <path d="M137.4 374.6c12.5 12.5 32.8 12.5 45.3 0l128-128c9.2-9.2 11.9-22.9 6.9-34.9s-16.6-19.8-29.6-19.8L32 192c-12.9 0-24.6 7.8-29.6 19.8s-2.2 25.7 6.9 34.9l128 128z" />
    </svg>
    """
  end

  # https://fontawesome.com/icons/sort?f=classic&s=solid
  defp sort_icon(assigns) do
    ~H"""
    <svg
      class="pax-icon pax-index-table-sort-icon"
      xmlns="http://www.w3.org/2000/svg"
      viewBox="0 0 320 512"
      height="1em"
      width="1em"
    >
      <!--!Font Awesome Free 6.7.2 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free Copyright 2025 Fonticons, Inc.-->
      <path d="M137.4 41.4c12.5-12.5 32.8-12.5 45.3 0l128 128c9.2 9.2 11.9 22.9 6.9 34.9s-16.6 19.8-29.6 19.8L32 224c-12.9 0-24.6-7.8-29.6-19.8s-2.2-25.7 6.9-34.9l128-128zm0 429.3l-128-128c-9.2-9.2-11.9-22.9-6.9-34.9s16.6-19.8 29.6-19.8l256 0c12.9 0 24.6 7.8 29.6 19.8s2.2 25.7-6.9 34.9l-128 128c-12.5 12.5-32.8 12.5-45.3 0z" />
    </svg>
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

  defp sortable?(%Pax.Field{opts: %{sort: _sort_field}}), do: true
  defp sortable?(_field), do: false

  defp sort_link(%Pax.Field{opts: %{sort: sort_field}} = field, pax) do
    sort_asc = field.opts[:sort_asc] || :asc
    sort_desc = field.opts[:sort_desc] || :desc
    %{path: path, private: %{index_table: %{default_sort_params: default_sort_params, sorts: sorts}}} = pax
    {_sort_num, sort_direction} = sorts[sort_field] || {nil, nil}

    if sort_direction == sort_asc do
      value = sort_param({sort_desc, sort_field})
      with_params(path, sort: [value: value, default: default_sort_params], page: nil)
    else
      value = sort_param({sort_asc, sort_field})
      with_params(path, sort: [value: value, default: default_sort_params], page: nil)
    end
  end

  defp sort_link(_field, _assigns), do: nil

  defp default_sort_params(%{assigns: %{pax: %{fields: fields, default_criteria: %{order_by: order_by}}}}) do
    field_sorts =
      for field <- fields, field.opts[:sort] != nil, into: %{} do
        {field.opts[:sort], %{asc: field.opts[:sort_asc] || :asc, desc: field.opts[:sort_desc] || :desc}}
      end

    case order_by do
      field_name when is_atom(field_name) ->
        sort_param({field_sorts[field_name][:asc], field_name})

      [field_name] when is_atom(field_name) ->
        sort_param({field_sorts[field_name][:asc], field_name})

      [{direction, field_name}] when is_atom(direction) and is_atom(field_name) ->
        sort_param({direction, field_name})

      order_by when is_list(order_by) ->
        for order <- order_by do
          case order do
            field_name when is_atom(field_name) ->
              sort_param({field_sorts[field_name][:asc], field_name})

            {direction, field_name} when is_atom(direction) and is_atom(field_name) ->
              sort_param({direction, field_name})

            _ ->
              nil
          end
        end
    end
  end

  defp default_sort_params(_pax), do: nil

  defp sort_param({:asc, field_name}), do: "#{field_name}"
  defp sort_param({:asc_nulls_first, field_name}), do: "~#{field_name}"
  defp sort_param({:asc_nulls_last, field_name}), do: ".#{field_name}"
  defp sort_param({:desc, field_name}), do: "-#{field_name}"
  defp sort_param({:desc_nulls_first, field_name}), do: "-~#{field_name}"
  defp sort_param({:desc_nulls_last, field_name}), do: "-.#{field_name}"
  defp sort_param(_field), do: nil

  defp field_sorted?(%Pax.Field{opts: %{sort: sort_field}}, %{private: %{index_table: %{sorts: sorts}}}) do
    Map.has_key?(sorts, sort_field)
  end

  defp field_sorted?(%Pax.Field{name: field_name}, %{private: %{index_table: %{sorts: sorts}}}) do
    Map.has_key?(sorts, field_name)
  end

  defp field_sorted?(_field, _pax), do: false

  defp sort_num(%Pax.Field{opts: %{sort: sort_field}}, %{private: %{index_table: %{sorts: sorts}}}) do
    {sort_num, _sort_direction} = sorts[sort_field] || {nil, nil}
    sort_num
  end

  defp sort_num(%Pax.Field{name: field_name}, %{private: %{index_table: %{sorts: sorts}}}) do
    {sort_num, _sort_direction} = sorts[field_name] || {nil, nil}
    sort_num
  end

  defp sort_num(_field, _pax), do: nil

  defp num_sorts(%{private: %{index_table: %{sorts: sorts}}}), do: map_size(sorts)
  defp num_sorts(_pax), do: 0

  defp sort_direction(%Pax.Field{opts: %{sort: sort_field}}, %{private: %{index_table: %{sorts: sorts}}}) do
    {_sort_num, sort_direction} = sorts[sort_field] || {nil, nil}
    sort_direction
  end

  defp sort_direction(%Pax.Field{name: field_name}, %{private: %{index_table: %{sorts: sorts}}}) do
    {_sort_num, sort_direction} = sorts[field_name] || {nil, nil}
    sort_direction
  end

  defp sort_direction(_field, _sorts), do: nil
end
