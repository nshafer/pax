defmodule SandboxWeb.LabelLive do
  use SandboxWeb, :live_view
  use Pax.Interface

  def render(assigns) do
    # dbg(assigns[:pax])

    ~H"""
    <Layouts.app flash={@flash}>
      {Pax.Interface.Components.pax_interface(assigns)}
    </Layouts.app>
    """
  end

  def pax_adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: Sandbox.Repo, schema: Sandbox.Library.Label}
  end

  def pax_plugins(_socket) do
    [
      Pax.Plugins.Breadcrumbs,
      Pax.Plugins.Title,
      Pax.Plugins.Pagination,
      Pax.Plugins.IndexTable,
      Pax.Plugins.DetailList
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
        {:id, immutable: true},
        {:name, only: [:show, :edit, :new]},
        {:name_link, :string, value: :name, link: true, only: :index},
        {:slug, except: [:index]},
        :founded,
        {:rating, :float, title: "Rating (0-5)", round: 3, required: false, only: :edit},
        {:rating_formatted, :string, value: &format_rating/1, except: [:edit]},
        {:accepting_submissions, :boolean, true: "Yes", false: "No"},
        {:inserted_at, :datetime, immutable: true, except: :index},
        {:updated_at, :datetime, immutable: true, except: :index}
      ],
      plugins: [
        pagination: [
          # objects_per_page: 2
        ],
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
