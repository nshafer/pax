defmodule SandboxWeb.Admin.AshLabelResource do
  @moduledoc """
  The same labels as `SandboxWeb.Admin.LabelResource`, through `Pax.Adapters.Ash` instead.

  `Sandbox.Catalog.Label` only has a read action, so this is a read-only interface.
  """
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.Ash, resource: Sandbox.Catalog.Label}
  end

  def config(_socket) do
    [
      object_name: fn object, _socket -> object.name end,
      fields: [
        {:name, :string, link: true, sort: true},
        {:slug, :string, except: :index},
        {:founded, :integer, sort: true},
        {:rating, :float, round: 2, required: false, sort: true},
        {:accepting_submissions, :boolean, true: "Yes", false: "No", sort: true}
      ],
      default_criteria: [order_by: :name]
    ]
  end
end
