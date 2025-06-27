defmodule SandboxWeb.LabelLive do
  use SandboxWeb, :live_view
  use Pax.Interface

  def render(assigns) do
    # dbg(assigns.pax)

    ~H"""
    <Layouts.app flash={@flash}>
      <Pax.Interface.Components.pax_interface :if={assigns[:pax]} pax={@pax} />

      <p>
        Counter: {@counter}
        <button class="btn" phx-click="increment">Increment</button>
        <button class="btn" phx-click="append_title">Append title</button>
      </p>
    </Layouts.app>
    """
  end

  def mount(_params, _session, socket) do
    {:ok, assign(socket, counter: 0)}
  end

  def handle_event("increment", _params, socket) do
    {:noreply, update(socket, :counter, &(&1 + 1))}
  end

  def handle_event("append_title", _params, socket) do
    plural_name = socket.assigns.pax.plural_name
    {:noreply, assign_pax(socket, :plural_name, plural_name <> ".")}
  end

  # def pax_init(_params, _session, socket) do
  #   {:halt, socket}
  # end

  def pax_adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Label}
  end

  def pax_plugins(_socket) do
    [
      Pax.Plugins.Breadcrumbs,
      Pax.Plugins.Title,
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailList,
      Pax.Plugins.Pagination,
      Pax.Plugins.ActionButtons
    ]
  end

  def pax_config(_socket) do
    [
      index_path: ~p"/labels",
      new_path: ~p"/labels/new",
      show_path: fn object, _socket -> ~p"/labels/#{object}" end,
      edit_path: fn object, _socket -> ~p"/labels/#{object}/edit" end,
      object_name: fn object, _socket -> object.name end,
      fields: [
        {:id, immutable: true, sort: true},
        {:name, only: [:show, :edit, :new]},
        {:name_link, :string, value: :name, sort: :name, link: true, only: :index},
        {:slug, except: [:index]},
        {:founded, sort: true},
        {:rating, :float, title: "Rating (0-5)", round: 3, required: false, only: :edit},
        {:rating_formatted, :string,
         value: &format_rating/1,
         sort: :rating,
         sort_asc: :asc_nulls_first,
         sort_desc: :desc_nulls_last,
         except: [:edit]},
        {:accepting_submissions, :boolean, true: "Yes", false: "No", sort: true},
        {:inserted_at, :datetime, immutable: true, except: :index},
        {:updated_at, :datetime, immutable: true, except: :index}
      ],
      default_scope: [
        order_by: :name
        # order_by: [asc: :name]
        # order_by: [asc_nulls_first: :name]
        # order_by: [asc: :name, desc: :name]
        # order_by: [asc_nulls_first: :rating]
        # order_by: :inserted_at
        # order_by: [:founded, :name]
        # order_by: [:founded, desc: :name]
        # order_by: [desc: :founded, asc: :name]
      ],
      plugins: [
        detail_list: [
          fields: [
            :name,
            :slug,
            :founded,
            :rating,
            :rating_formatted,
            :accepting_submissions,
            :inserted_at,
            :updated_at
          ]
        ]
      ]
    ]
  end

  def format_rating(%{rating: nil}), do: "-"
  def format_rating(%{rating: rating}), do: rating |> Float.round(2) |> Float.to_string()
end
