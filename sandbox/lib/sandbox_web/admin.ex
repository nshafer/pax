defmodule SandboxWeb.Admin do
  use Pax.Admin, router: SandboxWeb.Router
  # use Phoenix.Component

  # def render_index(assigns) do
  #   ~H"""
  #   <h1 class="text-2xl mb-3 flex justify-between">Labels <small>SandboxWeb.Admin</small></h1>
  #   <Pax.Index.Components.index pax_fields={@pax_fields} objects={@objects} />
  #   """
  # end

  config title: "Sandbox Admin"

  resource :labels, SandboxWeb.Admin.LabelResource
  resource :artists, SandboxWeb.Admin.ArtistResource
  resource :albums, SandboxWeb.Admin.AlbumResource

  # # link "More info", "https://somewhere.com/asdf"

  # section :library do
  #   resource :labels, SandboxWeb.Admin.LabelResource
  #   resource :artists, SandboxWeb.Admin.ArtistResource
  #   resource :albums, SandboxWeb.Admin.AlbumResource
  #   resource :albums2, SandboxWeb.Admin.AlbumResource, label: "Second Albums"
  #   # page :info, "Information", SandboxWeb.Admin.InfoPage
  # end

  # resource :labels2, SandboxWeb.Admin.LabelResource
  # resource :artists2, SandboxWeb.Admin.ArtistResource
  # resource :albums2, SandboxWeb.Admin.AlbumResource

  # section :library2, label: "Music Library Two" do
  #   resource :albums_two, SandboxWeb.Admin.AlbumResource
  # end

  # def config(_params, _session, _socket) do
  #   %{
  #     title: "Pax Demo Admin at Runtime"
  #   }
  # end

  # def resources(_params, _session, _socket) do
  #   [
  #     label: %{title: "Labels", resource: SandboxWeb.Admin.LabelResource},
  #     artist: %{resource: SandboxWeb.Admin.ArtistResource, some_opt: "asdf"},
  #     music_library: [
  #       label: %{resource: SandboxWeb.Admin.LabelResource},
  #       artist: %{resource: SandboxWeb.Admin.ArtistResource},
  #       album: %{resource: SandboxWeb.Admin.AlbumResource}
  #     ],
  #     library2: %{
  #       title: "Music Library Two",
  #       resources: [
  #         album: %{resource: SandboxWeb.Admin.AlbumResource}
  #       ]
  #     }
  #   ]
  # end
end
