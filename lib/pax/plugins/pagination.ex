defmodule Pax.Plugins.Pagination do
  use Pax.Interface.Plugin
  use Phoenix.Component
  import Pax.Components
  import Pax.Interface.Context
  import Pax.Util.URI

  @default_objects_per_page 10
  @default_count_placement :index_footer_primary
  @default_pager_placement :index_footer_secondary

  # Plugin callbacks

  @impl true
  def init(_callback_module, opts) do
    %{
      objects_per_page: Keyword.get(opts, :objects_per_page, @default_objects_per_page),
      count_placement: Keyword.get(opts, :count_placement, @default_count_placement),
      pager_placement: Keyword.get(opts, :pager_placement, @default_pager_placement)
    }
  end

  @impl true
  def config_key(), do: :pagination

  @impl true
  def config_spec() do
    %{
      objects_per_page: [:integer, {:function, 1, :integer}],
      count_placement: [:atom, {:function, 1, :atom}],
      pager_placement: [:atom, {:function, 1, :atom}]
    }
  end

  @impl true
  def merge_config(opts, config, socket) do
    %{
      objects_per_page: Pax.Config.get(config, :objects_per_page, [socket], opts.objects_per_page),
      count_placement: Pax.Config.get(config, :count_placement, [socket], opts.count_placement),
      pager_placement: Pax.Config.get(config, :pager_placement, [socket], opts.pager_placement)
    }
  end

  @impl true
  def handle_params(opts, params, _uri, socket) do
    if socket.assigns.pax.action == :index do
      # IO.inspect(params, label: "Pagination.handle_params")
      page = get_page(params)
      limit = opts.objects_per_page
      offset = (page - 1) * limit

      socket =
        socket
        |> assign_pax_private(:pagination, limit: limit)
        |> assign_pax_private(:pagination, page: page)
        |> assign_pax_private(:pagination, page_input_has_errors: false)
        |> assign_pax_scope(limit: limit, offset: offset)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  @impl true
  def after_params(_opts, socket) do
    if socket.assigns.pax.action == :index do
      num_pages = calculate_num_pages(socket)
      page = socket.assigns.pax.private.pagination.page
      has_prev = page > 1
      has_next = page < num_pages

      socket =
        socket
        |> assign_pax_private(:pagination, num_pages: num_pages)
        |> assign_pax_private(:pagination, has_prev: has_prev)
        |> assign_pax_private(:pagination, has_next: has_next)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  @impl true
  def handle_event(_opts, "pagination-page-change", params, socket) do
    params
    |> get_page(nil)
    |> update_page_event(socket)
  end

  @impl true
  def handle_event(_opts, "pagination-page-submit", params, socket) do
    params
    |> get_page(nil)
    |> update_page_event(socket)
  end

  def handle_event(_opts, _event, _params, socket), do: {:cont, socket}

  def update_page_event(page, socket) do
    if page != nil and page > 0 and page <= socket.assigns.pax.private.pagination.num_pages do
      socket =
        socket
        |> assign_pax_private(:pagination, :page_input_has_errors, false)
        |> Phoenix.LiveView.push_patch(to: with_params(socket.assigns.pax.path, page: [value: page, default: 1]))

      {:halt, socket}
    else
      {:halt, assign_pax_private(socket, :pagination, :page_input_has_errors, true)}
    end
  end

  # Utilities

  defp get_page(params, default \\ 1) do
    with(
      {:ok, page_str} <- Map.fetch(params, "page"),
      {page, ""} <- Integer.parse(page_str),
      page when page > 0 <- page
    ) do
      page
    else
      _ -> default
    end
  end

  defp calculate_num_pages(socket) do
    (socket.assigns.pax.object_count / socket.assigns.pax.private.pagination.limit)
    |> Float.ceil()
    |> round()
  end

  # Components

  @impl true
  def render(%{count_placement: count_placement}, count_placement, assigns) do
    ~H"""
    <div><b>Page:</b> {@pax.private.pagination.page} / {@pax.private.pagination.num_pages}</div>
    <div><b>Total:</b> {@pax.object_count}</div>
    """
  end

  def render(%{pager_placement: pager_placement}, pager_placement, assigns) do
    ~H"""
    <nav class="pax-pagination" aria-label="Page Navigation">
      <%!-- Link to first page (<<) --%>
      <.pax_link
        class={["pax-pagination-link", !@pax.private.pagination.has_prev && "disabled"]}
        patch={with_params(@pax.path, page: nil)}
      >
        <.angles_left />
      </.pax_link>

      <%!-- Link to previous page (<) --%>
      <.pax_link
        class={["pax-pagination-link", !@pax.private.pagination.has_prev && "disabled"]}
        patch={with_params(@pax.path, page: [value: @pax.private.pagination.page - 1, default: 1])}
      >
        <.angle_left />
      </.pax_link>

      <%!-- If there are less than 10 pages, show select, otherwise show a number input --%>
      <form phx-change="pagination-page-change" phx-submit="pagination-page-submit">
        <%= if @pax.private.pagination.num_pages <= 10 do %>
          <.pax_select
            class="pax-pagination-page-select"
            name="page"
            value={@pax.private.pagination.page}
            options={options_for_page_select(@pax.private.pagination.num_pages)}
            has_errors={@pax.private.pagination.page_input_has_errors}
            disabled={@pax.private.pagination.num_pages < 2}
          />
        <% else %>
          <.pax_input
            class="pax-pagination-page-input"
            name="page"
            type="text"
            inputmode="numeric"
            pattern="[0-9]*"
            value={@pax.private.pagination.page}
            phx-debounce
            has_errors={@pax.private.pagination.page_input_has_errors}
          />
        <% end %>
      </form>

      <%!-- Link to next page (>) --%>
      <.pax_link
        class={["pax-pagination-link", !@pax.private.pagination.has_next && "disabled"]}
        patch={with_params(@pax.path, page: [value: @pax.private.pagination.page + 1, default: 1])}
      >
        <.angle_right />
      </.pax_link>

      <%!-- Link to last page (>>) --%>
      <.pax_link
        class={["pax-pagination-link", !@pax.private.pagination.has_next && "disabled"]}
        patch={with_params(@pax.path, page: [value: @pax.private.pagination.num_pages, default: 1])}
      >
        <.angles_right />
      </.pax_link>
    </nav>
    """
  end

  def render(_opts, _component, _assigns), do: nil

  defp options_for_page_select(num_pages) do
    for p <- 1..num_pages do
      {p, p}
    end
  end

  defp angles_left(assigns) do
    ~H"""
    <svg class="pax-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" height="1em" width="1em">
      <!--! Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2023 Fonticons, Inc. -->
      <path d="M41.4 233.4c-12.5 12.5-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L109.3 256 246.6 118.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0l-160 160zm352-160l-160 160c-12.5 12.5-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L301.3 256 438.6 118.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0z" />
    </svg>
    """
  end

  defp angles_right(assigns) do
    ~H"""
    <svg class="pax-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512" height="1em" width="1em">
      <!--! Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2023 Fonticons, Inc. -->
      <path d="M470.6 278.6c12.5-12.5 12.5-32.8 0-45.3l-160-160c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L402.7 256 265.4 393.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0l160-160zm-352 160l160-160c12.5-12.5 12.5-32.8 0-45.3l-160-160c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L210.7 256 73.4 393.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0z" />
    </svg>
    """
  end

  defp angle_left(assigns) do
    ~H"""
    <svg class="pax-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512" height="1em" width="1em">
      <!--! Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2023 Fonticons, Inc. -->
      <path d="M41.4 233.4c-12.5 12.5-12.5 32.8 0 45.3l160 160c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L109.3 256 246.6 118.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0l-160 160z" />
    </svg>
    """
  end

  defp angle_right(assigns) do
    ~H"""
    <svg class="pax-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 512" height="1em" width="1em">
      <!--! Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2023 Fonticons, Inc. -->
      <path d="M278.6 233.4c12.5 12.5 12.5 32.8 0 45.3l-160 160c-12.5 12.5-32.8 12.5-45.3 0s-12.5-32.8 0-45.3L210.7 256 73.4 118.6c-12.5-12.5-12.5-32.8 0-45.3s32.8-12.5 45.3 0l160 160z" />
    </svg>
    """
  end

  # defp ellipsis(assigns) do
  #   ~H"""
  #   <svg class="pax-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 448 512" height="1em" width="1em">
  #     <!--! Font Awesome Free 6.5.1 by @fontawesome - https://fontawesome.com License - https://fontawesome.com/license/free (Icons: CC BY 4.0, Fonts: SIL OFL 1.1, Code: MIT License) Copyright 2023 Fonticons, Inc. -->
  #     <path d="M8 256a56 56 0 1 1 112 0A56 56 0 1 1 8 256zm160 0a56 56 0 1 1 112 0 56 56 0 1 1 -112 0zm216-56a56 56 0 1 1 0 112 56 56 0 1 1 0-112z" />
  #   </svg>
  #   """
  # end
end
