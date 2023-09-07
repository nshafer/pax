defmodule Pax.Admin.Router do
  defmacro __using__(_opts) do
    quote do
      import Pax.Admin.Router
      @before_compile Pax.Admin.Router
      @pax_paths %{}
    end
  end

  defmacro pax_admin(path, site_mod, opts \\ []) do
    site_mod = Macro.expand(site_mod, __CALLER__)

    quote bind_quoted: binding() do
      {full_path, full_site_mod, dashboard_mod, dashboard_opts, index_mod, index_opts, detail_mod, detail_opts} =
        Pax.Admin.Router.__pax_admin__(__MODULE__, path, site_mod, opts)

      @pax_paths Map.put(@pax_paths, full_site_mod, full_path)

      live "#{path}", dashboard_mod, :dashboard, dashboard_opts

      # TODO: pass full_site_mod to live view via metadata
      live "#{path}/r/:resource", index_mod, :index, index_opts
      live "#{path}/r/:resource/new", detail_mod, :new, detail_opts
      live "#{path}/r/:resource/:id", detail_mod, :show, detail_opts
      live "#{path}/r/:resource/:id/edit", detail_mod, :edit, detail_opts
      live "#{path}/r/:resource/:id/delete", detail_mod, :delete, detail_opts

      live "#{path}/:section/r/:resource", index_mod, :index, index_opts
      live "#{path}/:section/r/:resource/new", detail_mod, :new, detail_opts
      live "#{path}/:section/r/:resource/:id", detail_mod, :show, detail_opts
      live "#{path}/:section/r/:resource/:id/edit", detail_mod, :edit, detail_opts
      live "#{path}/:section/r/:resource/:id/delete", detail_mod, :delete, detail_opts
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

    dashboard_mod = Module.concat(site_mod, DashboardLive)
    dashboard_opts = Keyword.put(opts, :as, :"#{base_as}_dashboard")

    index_mod = Module.concat(site_mod, IndexLive)
    index_opts = Keyword.put(opts, :as, :"#{base_as}_index")

    detail_mod = Module.concat(site_mod, DetailLive)
    detail_opts = Keyword.put(opts, :as, :"#{base_as}_detail")

    {full_path, full_site_mod, dashboard_mod, dashboard_opts, index_mod, index_opts, detail_mod, detail_opts}
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
