defmodule Pax.Admin.Router do
  defmacro __using__(_opts) do
    quote do
      import Pax.Admin.Router
      @before_compile Pax.Admin.Router
      @pax_paths %{}
    end
  end

  defmacro pax_admin(path, admin_mod, opts \\ []) do
    admin_mod = Macro.expand(admin_mod, __CALLER__)

    quote bind_quoted: binding() do
      full_path = Phoenix.Router.scoped_path(__MODULE__, path)
      full_admin_mod = Phoenix.Router.scoped_alias(__MODULE__, admin_mod)
      @pax_paths Map.put(@pax_paths, full_admin_mod, full_path)

      index_mod = Module.concat(admin_mod, IndexLive)
      detail_mod = Module.concat(admin_mod, DetailLive)

      live "#{path}/:section/:resource", index_mod, :index, opts
      live "#{path}/:section/:resource/new", detail_mod, :new, opts
      live "#{path}/:section/:resource/:id", detail_mod, :show, opts
      live "#{path}/:section/:resource/:id/edit", detail_mod, :edit, opts
      live "#{path}/:section/:resource/:id/delete", detail_mod, :delete, opts

      live "#{path}/:resource", index_mod, :index, opts
      live "#{path}/:resource/new", detail_mod, :new, opts
      live "#{path}/:resource/:id", detail_mod, :show, opts
      live "#{path}/:resource/:id/edit", detail_mod, :edit, opts
      live "#{path}/:resource/:id/delete", detail_mod, :delete, opts
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def __pax__(:paths), do: @pax_paths
    end
  end
end
