defmodule Pax.Admin.Router do
  @moduledoc """
  Provides functionality for mounting Pax.Admin sites in your router.

  > #### `use Pax.Admin.Router` {: .info}
  >
  > When you `use Pax.Admin.Router` the `pax_admin/3` macro will be imported for use in your router. A module attribute
  > called `@pax_paths` will also be defined. This attribute is used by `Pax.Admin.Site` to determine the path
  > to a given admin site. It will be exposed with a `__pax__/1` function that returns a map of site modules to
  > paths when called with `:paths`.

  Note: This must be done in your main Router, not in a Router that is forwarded from another router. This is currently
  a limitation of LiveView per https://github.com/phoenixframework/phoenix_live_view/issues/476.
  """
  require Phoenix.LiveView.Router

  defmacro __using__(_opts) do
    quote do
      import Pax.Admin.Router
      @before_compile Pax.Admin.Router
      @pax_paths %{}
    end
  end

  @doc """
  Mounts a Pax.Admin.Site at the given path in your router.

  This macro will define a `live_session` block that contains many `Phoenix.LiveView.Router.live/4` calls to define
  endpoints for the admin site. If router helpers are enabled, then it will generate route helper names based on the
  Site module's name.

  ## Options

    * `:as` - The name to use for the route helpers. Defaults to the underscored version of the Site module's name.

    * `:root_layout` - An optional root layout tuple for the initial HTTP render. Defaults to
      `{Pax.Admin.Layouts, :root}`.

    * `:layout` - An optional layout tuple for the Admin interface. Defaults to `{Pax.Admin.Layouts, :admin}`.

    * `:on_mount` - The optional list of hooks to attach to the mount lifecycle _of each LiveView in the session_.
      See `Phoenix.LiveView.on_mount/1`. Passing a single value is also accepted.

  ## Examples

        scope "/", PaxDemoWeb do
          pipe_through [:browser]

          pax_admin "/admin", MainAdmin.Site,
            as: :admin,
            on_mount: {MyAppWeb.AdminAuth, :ensure_user_is_admin}
          pax_admin "/public/admin", PublicAdmin.Site
        end

  """
  defmacro pax_admin(path, site_mod, opts \\ []) do
    site_mod = Macro.expand(site_mod, __CALLER__)

    quote bind_quoted: binding() do
      {full_path, full_site_mod, modules, opts} =
        Pax.Admin.Router.__pax_admin__(__MODULE__, path, site_mod, opts)

      @pax_paths Map.put(@pax_paths, full_site_mod, full_path)

      live_session site_mod, opts.live_session do
        live "#{path}", modules.dashboard, :dashboard, opts.dashboard

        live "#{path}/r/:resource", modules.resource, :index, opts.resource
        live "#{path}/r/:resource/new", modules.resource, :new, opts.resource
        live "#{path}/r/:resource/edit/*ids", modules.resource, :edit, opts.resource
        live "#{path}/r/:resource/delete/*ids", modules.resource, :delete, opts.resource
        live "#{path}/r/:resource/*ids", modules.resource, :show, opts.resource

        live "#{path}/:section/r/:resource", modules.resource, :index, opts.resource
        live "#{path}/:section/r/:resource/new", modules.resource, :new, opts.resource
        live "#{path}/:section/r/:resource/edit/*ids", modules.resource, :edit, opts.resource
        live "#{path}/:section/r/:resource/delete/*ids", modules.resource, :delete, opts.resource
        live "#{path}/:section/r/:resource/*ids", modules.resource, :show, opts.resource
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __pax__(:paths), do: @pax_paths
    end
  end

  def __pax_admin__(router_mod, path, site_mod, opts) do
    full_path = Phoenix.Router.scoped_path(router_mod, path)
    full_site_mod = Phoenix.Router.scoped_alias(router_mod, site_mod)
    base_as = as_from_site_mod(opts[:as], full_site_mod)

    modules = %{
      dashboard: Module.concat(site_mod, DashboardLive),
      resource: Module.concat(site_mod, ResourceLive)
    }

    live_session_opts =
      [
        root_layout: Keyword.get(opts, :root_layout, {Pax.Admin.Layouts, :root}),
        layout: Keyword.get(opts, :layout, {Pax.Admin.Layouts, :admin})
      ]
      |> Keyword.merge(Keyword.take(opts, [:session, :on_mount]))

    opts = %{
      live_session: live_session_opts,
      dashboard: [as: :"#{base_as}_dashboard"],
      resource: [as: :"#{base_as}_resource"]
    }

    {full_path, full_site_mod, modules, opts}
  end

  defp as_from_site_mod(nil, site_mod) do
    site_mod
    |> Module.split()
    |> Enum.drop_while(&(not String.ends_with?(&1, "Admin")))
    |> Enum.map(&(&1 |> String.replace_suffix("Site", "") |> Macro.underscore()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("_")
    |> case do
      "" ->
        raise ArgumentError,
              "could not infer :as option from #{site_mod} because it does not have an \"Admin\" suffix " <>
                "anywhere in the module path. Please pass :as explicitly or make sure your admin site is " <>
                "named like \"MyAppWeb.Admin.Site\" or \"MyAppWeb.MainAdmin\". This must be provided even " <>
                "if you don't have `helpers: true` in your Router or use path helpers."

      as ->
        String.to_atom(as)
    end
  end

  defp as_from_site_mod(as, _site_mod), do: as
end
