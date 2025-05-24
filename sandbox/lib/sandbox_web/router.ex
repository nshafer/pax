defmodule SandboxWeb.Router do
  use SandboxWeb, :router
  use Pax.Admin.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {SandboxWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", SandboxWeb do
    pipe_through :browser

    get "/", PageController, :home

    live_session :default do
      live "/labels", LabelLive, :index
      live "/labels/new", LabelLive, :new
      live "/labels/:id", LabelLive, :show
      live "/labels/:id/edit", LabelLive, :edit
      live "/labels/:id/delete", LabelLive, :delete

      live "/artists", ArtistLive, :index
      live "/artists/new", ArtistLive, :new
      live "/artists/:slug", ArtistLive, :show
      live "/artists/:slug/edit", ArtistLive, :edit
      live "/artists/:slug/delete", ArtistLive, :delete

      live "/albums", AlbumLive, :index
      live "/albums/new", AlbumLive, :new
      live "/albums/:uuid", AlbumLive, :show
      live "/albums/:uuid/edit", AlbumLive, :edit
      live "/albums/:uuid/delete", AlbumLive, :delete
    end

    pax_admin "/admin", Admin.Site, as: :admin
  end

  # Other scopes may use custom stacks.
  # scope "/api", SandboxWeb do
  #   pipe_through :api
  # end
end
