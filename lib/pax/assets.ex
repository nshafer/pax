defmodule Pax.Assets do
  @moduledoc """
  Handles serving static assets for Pax, including Pax.Admin.

  This plug serves CSS, JS and other static assets at the `/pax` path by default. It should be used in your endpoint,
  after any `socket` lines, and before `plug Plug.Parsers`. Usually after your existing `Plug.Static` plug, for example:

      plug Pax.Assets

  You can change this by passing the
  `:at` option when adding the plug to your endpoint, for example:

      plug Pax.Assets, at: "/custom_path"

  If you change the `:at` option, make sure to also update your custom root templates to use the same path when
  including the Pax assets, for example:

      <Pax.Components.assets at="/custom_path" />
      <Pax.Admin.Components.assets at="/custom_path" />

  ## Options

    * `:at` - The base path to serve the assets from. Defaults to `"/pax"`.
    * `:static_opts` - Options to pass to the underlying `Plug.Static` plug for serving static files. See `Plug.Static`
      documentation for available options. Defaults to serving from the `:pax` app at `"/pax/static"` with gzip
      enabled.
    * `:cache_control` - The value to use for the `Cache-Control` header when serving assets. Defaults to
      `"public, max-age=31536000, immutable"`.
    * `:logging` - Whether to log asset requests. Defaults to `false`.

  ## Asset bundling

  By default, Pax bundles its CSS and JS assets into the compiled application for performance. This means that changes
  to the CSS and JS files will not be picked up until the Pax application is recompiled. This is usually what you want
  in a production environment.

  When developing Pax itself, you may want to disable asset bundling so that changes to the CSS and JS files are
  picked up without recompiling the entire Pax application. You can do this by setting the `:enable_asset_bundling`
  config option for the `:pax` application to `false` in your `config/dev.exs` file:

      config :pax, enable_asset_bundling: false

  Similarly, if you are developing the Pax Admin interface, you can disable admin asset bundling by setting the
  `:enable_admin_asset_bundling` config option for the `:pax` application to `false` in your `config/dev.exs` file:

      config :pax, enable_admin_asset_bundling: false

  After making these changes you must `mix deps.compile --force pax` to recompile pax with the new setting.
  """

  import Plug.Conn
  require Logger

  @behaviour Plug
  @allowed_methods ~w(GET HEAD)

  @impl true
  def init(opts) do
    at = Keyword.get(opts, :at, "/pax")
    cache_control = Keyword.get(opts, :cache_control, "public, max-age=31536000, immutable")
    default_static_opts = [at: "#{at}/static", from: :pax, gzip: true]
    static_opts = Keyword.merge(default_static_opts, Keyword.get(opts, :static_opts, []))
    logging = Keyword.get(opts, :logging, false)

    %{
      at: at |> Plug.Router.Utils.split(),
      cache_control: cache_control,
      static_opts: Plug.Static.init(static_opts),
      logging: logging
    }
  end

  @impl true
  def call(%Plug.Conn{method: method} = conn, opts) when method in @allowed_methods do
    segments = subset(opts.at, conn.path_info)

    if allowed?(segments) do
      if opts.logging, do: Logger.info("[Pax.Assets] #{method} #{format_request(conn)}")

      # TODO: Handle plugin assets as well
      case segments do
        ["admin", "assets" | segments] -> Pax.Admin.Assets.serve(conn, segments, cache_control: opts.cache_control)
        ["assets" | segments] -> serve(conn, segments, cache_control: opts.cache_control)
        ["static" | _segments] -> Plug.Static.call(conn, opts.static_opts)
      end
    else
      conn
    end
  end

  def call(conn, _opts) do
    conn
  end

  defp format_request(%{request_path: path, query_string: ""}), do: path
  defp format_request(%{request_path: path, query_string: qs}), do: "#{path}?#{qs}"

  defp subset([h | expected], [h | actual]), do: subset(expected, actual)
  defp subset([], actual), do: actual
  defp subset(_, _), do: []

  defp allowed?([]), do: false
  defp allowed?(_path), do: true

  # Base asset paths of the built assets
  @css_path Path.join(__DIR__, "../../priv/assets/pax.css")
  @js_path Path.join(__DIR__, "../../priv/assets/pax.js")

  if Application.compile_env(:pax, :enable_asset_bundling, true) do
    # Read in the assets to a module attribute at compile time so it's bundled in the compiled bytecode
    @external_resource @css_path
    @css Pax.Util.Assets.read(@css_path)

    @external_resource @js_path
    @js Pax.Util.Assets.read(@js_path)

    defp asset_data("pax.css"), do: {@css, "text/css"}
    defp asset_data("pax.js"), do: {@js, "text/javascript"}
    defp asset_data(_), do: raise(Pax.Assets.NotFoundError, message: "Asset not found")

    @hashes %{
      :css => Base.encode16(:crypto.hash(:md5, @css), case: :lower),
      :js => Base.encode16(:crypto.hash(:md5, @js), case: :lower)
    }

    defp asset_hash(:css), do: @hashes[:css]
    defp asset_hash(:js), do: @hashes[:js]
  else
    # Read assets each time they are requested so changes are picked up without recompiling, useful when developing pax
    defp asset_data("pax.css"), do: {Pax.Util.Assets.read(@css_path), "text/css"}
    defp asset_data("pax.js"), do: {Pax.Util.Assets.read(@js_path), "text/javascript"}
    defp asset_data(_), do: raise(Pax.Assets.NotFoundError, message: "Asset not found")

    defp asset_hash(:css), do: Pax.Util.Assets.stat(@css_path, time: :posix).mtime
    defp asset_hash(:js), do: Pax.Util.Assets.stat(@js_path, time: :posix).mtime
  end

  defp serve(conn, [asset | _extra], opts) do
    {contents, content_type} = asset_data(asset)
    serve_static(conn, contents, content_type, opts)
  end

  @doc """
  Serves the given static contents with the given content type and options.

  Options:

    * `:cache_control` - The value to use for the `Cache-Control` header. Defaults to `"no-store"`.
  """
  def serve_static(conn, contents, content_type, opts) do
    cache_control = Keyword.get(opts, :cache_control, "no-store")

    conn
    |> put_resp_header("content-type", content_type)
    |> put_resp_header("cache-control", cache_control)
    |> send_resp(200, contents)
    |> halt()
  end

  @doc """
  Returns the current hash for the given `asset`.
  """
  def current_hash(:css), do: asset_hash(:css)
  def current_hash(:js), do: asset_hash(:js)

  @doc """
  Returns the path to the given `file` of type `:css` or `:js`, served from the given base path `at`, with a version
  query parameter based on the current hash of the asset.
  """
  def asset_path(type, at, file) when type in [:css, :js] do
    "#{at}/assets/#{file}?vsn=#{current_hash(type)}"
  end

  # Load the cache manifest at compile time if it exists
  @cache_manifest_path Path.join(__DIR__, "../../priv/static/cache_manifest.json")
  @external_resource @cache_manifest_path
  @cache_manifest_latest Pax.Util.Assets.read_cache_manifest(@cache_manifest_path, "latest")

  def static_path(at, path) do
    path = Map.get(@cache_manifest_latest, path, path)
    "#{at}/static/#{path}"
  end
end
