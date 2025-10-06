defmodule Pax.Admin.Assets do
  @moduledoc false
  require Logger

  # Include JS from the currently installed versions of the phoenix packages, preferring minified versions
  # if available This ensures that the JS included in the Pax Admin assets matches the versions used in
  # the host dependencies
  @phx_js_paths (for app <- [:phoenix, :phoenix_html, :phoenix_live_view] do
                   app_dir = Application.app_dir(app)
                   min_path = Path.join([app_dir, "priv", "static", "#{app}.min.js"])
                   path = Path.join([app_dir, "priv", "static", "#{app}.js"])

                   cond do
                     File.exists?(min_path) ->
                       Module.put_attribute(__MODULE__, :external_resource, min_path)
                       min_path

                     File.exists?(path) ->
                       Module.put_attribute(__MODULE__, :external_resource, path)
                       path

                     true ->
                       nil
                   end
                 end)

  # Admin asset paths
  @admin_css_path Path.join(__DIR__, "../../../priv/assets/pax_admin.css")
  @admin_js_path Path.join(__DIR__, "../../../priv/assets/pax_admin.js")

  if Application.compile_env(:pax, :enable_admin_asset_bundling, true) do
    # Read in the assets to a module attribute at compile time so it's bundled in the compiled bytecode, including
    # the found phoenix JS files
    @external_resource @admin_css_path
    @css Pax.Util.Assets.read(@admin_css_path)

    @external_resource @admin_js_path
    @js """
    #{for path <- @phx_js_paths, path != nil, do: Pax.Util.Assets.include(path)}
    #{Pax.Util.Assets.read(@admin_js_path)}
    """

    defp asset_data("pax_admin.css"), do: {@css, "text/css"}
    defp asset_data("pax_admin.js"), do: {@js, "text/javascript"}
    defp asset_data(_), do: raise(Pax.Assets.NotFoundError, message: "Asset not found")

    @hashes %{
      :css => Base.encode16(:crypto.hash(:md5, @css), case: :lower),
      :js => Base.encode16(:crypto.hash(:md5, @js), case: :lower)
    }

    defp asset_hash(:css), do: @hashes[:css]
    defp asset_hash(:js), do: @hashes[:js]
  else
    # Read assets each time they are requested so changes are picked up without recompiling, useful when developing pax
    defp asset_data("pax_admin.css"), do: {Pax.Util.Assets.read(@admin_css_path), "text/css"}

    defp asset_data("pax_admin.js") do
      contents =
        """
        #{for path <- @phx_js_paths, path != nil, do: Pax.Util.Assets.include(path)}
        #{Pax.Util.Assets.read(@admin_js_path)}
        """

      {contents, "text/javascript"}
    end

    defp asset_data(_), do: raise(Pax.Assets.NotFoundError, message: "Asset not found")

    defp asset_hash(:css), do: Pax.Util.Assets.stat(@admin_css_path, time: :posix).mtime
    defp asset_hash(:js), do: Pax.Util.Assets.stat(@admin_js_path, time: :posix).mtime
  end

  def serve(conn, [asset | _extra], opts) do
    {contents, content_type} = asset_data(asset)
    Pax.Assets.serve_static(conn, contents, content_type, opts)
  end

  @doc """
  Returns the current hash for the given `asset`.
  """
  def current_hash(:css), do: asset_hash(:css)
  def current_hash(:js), do: asset_hash(:js)

  def asset_path(type, at, file) when type in [:css, :js] do
    "#{at}/admin/assets/#{file}?vsn=#{current_hash(type)}"
  end
end
