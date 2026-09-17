defmodule PaxTest.Admin do
  @moduledoc "An admin defined with the `Pax.Admin` macros."
  use Pax.Admin, router: PaxTest.Router

  config title: "Test Admin"

  resource :books, PaxTest.Admin.BookResource

  section :library, label: "The Library" do
    resource :authors, PaxTest.Admin.AuthorResource
    resource :memberships, PaxTest.Admin.MembershipResource, label: "Members"
  end

  section :misc do
    resource :books, PaxTest.Admin.BookResource, label: "More Books"
    resource :custom_render, PaxTest.Admin.CustomRenderResource
  end
end

defmodule PaxTest.RuntimeAdmin do
  @moduledoc "An admin defined with the runtime `config/3` and `resources/3` callbacks."
  use Pax.Admin, router: PaxTest.Router

  def config(params, session, socket) do
    PaxTest.Owner.call(:runtime_admin_config, [params, session, socket], %{title: "Runtime Admin"})
  end

  def resources(params, session, socket) do
    PaxTest.Owner.call(:runtime_admin_resources, [params, session, socket], default_resources())
  end

  defp default_resources do
    [
      books: %{label: "Runtime Books", resource: PaxTest.Admin.BookResource, extra: "option"},
      library: [
        authors: %{resource: PaxTest.Admin.AuthorResource}
      ],
      archive: %{
        label: "The Archive",
        resources: [
          books: %{resource: PaxTest.Admin.BookResource}
        ]
      }
    ]
  end
end

defmodule PaxTest.CustomAdmin do
  @moduledoc "An admin with no config, a custom dashboard, mounted in a nested scope with an on_mount hook."
  use Pax.Admin, router: PaxTest.Router
  use Phoenix.Component

  resource :authors, PaxTest.Admin.AuthorResource

  def render_dashboard(assigns) do
    ~H"""
    <h1 id="custom-dashboard">Custom dashboard for {@hooked}</h1>
    """
  end

  defmodule Hook do
    def on_mount(:default, _params, _session, socket) do
      {:cont, Phoenix.Component.assign(socket, :hooked, "hooked")}
    end
  end
end

defmodule PaxTest.Admin.BookResource do
  @moduledoc "A resource backed by the EctoSchema adapter and the fake repo."
  use Pax.Admin.Resource

  def adapter(_socket) do
    {Pax.Adapters.EctoSchema, repo: PaxTest.Repo, schema: PaxTest.Book}
  end

  def config(socket) do
    PaxTest.Owner.call(:book_resource_config, [socket], [])
  end

  def plugins(socket) do
    PaxTest.Owner.call(:book_resource_plugins, [socket], super(socket))
  end
end

defmodule PaxTest.Admin.MembershipResource do
  @moduledoc "A resource with a composite primary key."
  use Pax.Admin.Resource

  def adapter(_socket), do: Pax.Adapters.EctoSchema

  def config(_socket) do
    [
      adapter: [repo: PaxTest.Repo, schema: PaxTest.Membership]
    ]
  end
end

defmodule PaxTest.Admin.AuthorResource do
  @moduledoc """
  A resource with no adapter, implementing every data callback over authors stored with `PaxTest.Owner`.
  """
  use Pax.Admin.Resource

  alias PaxTest.Author
  alias PaxTest.Owner

  def init(params, session, socket) do
    Owner.notify({:author_resource, :init, params, session})
    Owner.call(:author_resource_init, [params, session, socket], {:cont, socket})
  end

  def config(_socket) do
    [
      singular_name: "Author",
      plural_name: "Authors",
      object_name: fn author, _socket -> author.name end,
      fields: [
        {:name, :string, link: true},
        {:born, :integer, required: false},
        {:active, :boolean, true: "Yes", false: "No"}
      ]
    ]
  end

  def count_objects(_criteria, _socket), do: length(authors())
  def list_objects(_criteria, _socket), do: authors()
  def new_object(_socket), do: %Author{}

  def get_object(%{id: id}, _criteria, _socket) do
    Enum.find(authors(), &(to_string(&1.id) == id)) || raise "author #{id} not found"
  end

  def change_object(author, params, _socket), do: Author.changeset(author, params)

  def create_object(_author, changeset, _socket) do
    with {:ok, author} <- Ecto.Changeset.apply_action(changeset, :insert) do
      author = %{author | id: 99}
      Owner.notify({:author_resource, :created, author})
      {:ok, author}
    end
  end

  def update_object(_author, changeset, _socket) do
    with {:ok, author} <- Ecto.Changeset.apply_action(changeset, :update) do
      Owner.notify({:author_resource, :updated, author})
      {:ok, author}
    end
  end

  defp authors, do: Owner.get(:authors, [])
end

defmodule PaxTest.Admin.CustomRenderResource do
  @moduledoc "A resource that overrides rendering."
  use Pax.Admin.Resource
  use Phoenix.Component

  def render(assigns) do
    ~H"""
    <div id="custom-resource-render">Custom resource render</div>
    """
  end

  def list_objects(_criteria, _socket), do: []
  def count_objects(_criteria, _socket), do: 0
  def config(_socket), do: [fields: [{:name, :string}]]
end
