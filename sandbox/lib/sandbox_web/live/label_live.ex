defmodule SandboxWeb.LabelLive do
  use SandboxWeb, :live_view
  use Pax.Interface

  def render(assigns) do
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
      Pax.Plugins.IndexTable
    ]
  end

  def pax_config(_socket) do
    [
      index_path: ~p"/labels",
      new_path: ~p"/labels/new",
      show_path: fn object, _socket -> ~p"/labels/#{object}" end,
      edit_path: fn object, _socket -> ~p"/labels/#{object}/edit" end,
      object_name: fn object, _socket -> object.name end,
      index_fields: [
        :id,
        {:name, link: true},
        :founded,
        {:rating, :string, value: &format_rating/1},
        :accepting_submissions
      ],
      fieldsets: [
        default: [
          [:name, :slug],
          [
            :founded,
            {:rating, :float, title: "Rating (0-5)", round: 2, required: false}
          ],
          {:accepting_submissions, :boolean, true: "Yes", false: "No"}
        ],
        metadata: [
          {:id, immutable: true},
          {:inserted_at, :datetime, immutable: true},
          {:updated_at, :datetime, immutable: true}
        ]
      ],
      plugins: [
        pagination: [
          # objects_per_page: 2
        ]
      ]
    ]
  end

  def format_rating(%{rating: nil}), do: "-"
  def format_rating(%{rating: rating}), do: rating |> Float.round(2) |> Float.to_string()
end
