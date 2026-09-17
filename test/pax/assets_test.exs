defmodule Pax.AssetsTest do
  use ExUnit.Case, async: true

  import Plug.Test
  import Plug.Conn
  import ExUnit.CaptureLog

  @priv Path.expand("../../priv", __DIR__)

  defp call(conn, opts \\ []), do: Pax.Assets.call(conn, Pax.Assets.init(opts))

  # The assets are read at compile time, and are empty if they haven't been built
  defp built(path) do
    case File.read(Path.join(@priv, path)) do
      {:ok, contents} -> contents
      {:error, _} -> ""
    end
  end

  describe "init/1" do
    test "has defaults" do
      opts = Pax.Assets.init([])

      assert opts.at == ["pax"]
      assert opts.cache_control == "public, max-age=31536000, immutable"
      assert opts.logging == false
      assert %{at: ["pax", "static"], from: {:pax, "priv/static"}, encodings: [{"gzip", ".gz"}]} = opts.static_opts
    end

    test "accepts options" do
      opts = Pax.Assets.init(at: "/assets/pax", cache_control: "no-cache", logging: true, static_opts: [gzip: false])

      assert opts.at == ["assets", "pax"]
      assert opts.cache_control == "no-cache"
      assert opts.logging == true
      assert %{at: ["assets", "pax", "static"], encodings: []} = opts.static_opts
    end
  end

  describe "call/2" do
    test "serves the pax css and js" do
      conn = call(conn(:get, "/pax/assets/pax.css"))

      assert conn.halted
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/css"]
      assert get_resp_header(conn, "cache-control") == ["public, max-age=31536000, immutable"]
      assert conn.resp_body == built("assets/pax.css")

      conn = call(conn(:head, "/pax/assets/pax.js?vsn=123"), cache_control: "no-cache")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/javascript"]
      assert get_resp_header(conn, "cache-control") == ["no-cache"]
    end

    test "serves the admin css and js, including the phoenix js" do
      conn = call(conn(:get, "/pax/admin/assets/pax_admin.css"))

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/css"]
      assert conn.resp_body == built("assets/pax_admin.css")

      conn = call(conn(:get, "/pax/admin/assets/pax_admin.js"))

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") == ["text/javascript"]
      assert conn.resp_body =~ ~r"//__BEGIN__ .*/phoenix/priv/static/phoenix(\.min)?\.js"
      assert conn.resp_body =~ ~r"//__BEGIN__ .*/phoenix_html/priv/static/phoenix_html\.js"
      assert conn.resp_body =~ ~r"//__BEGIN__ .*/phoenix_live_view/priv/static/phoenix_live_view(\.min)?\.js"
      assert conn.resp_body =~ built("assets/pax_admin.js")
    end

    test "raises a 404 for unknown assets" do
      assert_raise Pax.Assets.NotFoundError, fn -> call(conn(:get, "/pax/assets/other.css")) end
      assert_raise Pax.Assets.NotFoundError, fn -> call(conn(:get, "/pax/admin/assets/other.css")) end
    end

    @tag :tmp_dir
    test "serves static files", %{tmp_dir: tmp_dir} do
      File.write!(Path.join(tmp_dir, "file.txt"), "static file")

      conn = call(conn(:get, "/pax/static/file.txt"), static_opts: [from: tmp_dir])

      assert conn.status == 200
      assert conn.resp_body == "static file"
    end

    test "serves from another path" do
      conn = call(conn(:get, "/assets/pax/assets/pax.css"), at: "/assets/pax")
      assert conn.status == 200

      conn = call(conn(:get, "/pax/assets/pax.css"), at: "/assets/pax")
      refute conn.halted
    end

    test "passes through other requests" do
      for conn <- [
            conn(:get, "/"),
            conn(:get, "/pax"),
            conn(:get, "/other/assets/pax.css"),
            conn(:post, "/pax/assets/pax.css")
          ] do
        conn = call(conn)
        refute conn.halted
        assert conn.status == nil
      end
    end

    @tag :known_bug
    test "passes through unknown paths under the mount point" do
      refute call(conn(:get, "/pax/unknown/file.css")).halted
      refute call(conn(:get, "/pax/assets")).halted
    end
  end

  describe "paths" do
    # (logging is tested in Pax.AssetsLoggingTest, which changes the global log level)

    test "asset_path/3 includes a hash of the asset" do
      assert Pax.Assets.asset_path(:css, "/pax", "pax.css") ==
               "/pax/assets/pax.css?vsn=#{Pax.Assets.current_hash(:css)}"

      assert Pax.Assets.asset_path(:js, "/x", "pax.js") == "/x/assets/pax.js?vsn=#{Pax.Assets.current_hash(:js)}"
      assert Pax.Assets.current_hash(:css) == Base.encode16(:crypto.hash(:md5, built("assets/pax.css")), case: :lower)

      assert Pax.Admin.Assets.asset_path(:css, "/pax", "pax_admin.css") ==
               "/pax/admin/assets/pax_admin.css?vsn=#{Pax.Admin.Assets.current_hash(:css)}"

      assert Pax.Admin.Assets.current_hash(:js) =~ ~r/^[0-9a-f]{32}$/
    end

    test "static_path/2 uses the digested file from the cache manifest" do
      manifest = Pax.Util.Assets.read_cache_manifest(Path.join(@priv, "static/cache_manifest.json"), "latest")

      for {file, digested} <- Enum.take(manifest, 1) do
        assert Pax.Assets.static_path("/pax", file) == "/pax/static/#{digested}"
      end

      assert Pax.Assets.static_path("/pax", "not/in/manifest.css") == "/pax/static/not/in/manifest.css"
    end

    test "serve_static/4 defaults to no caching" do
      conn = Pax.Assets.serve_static(conn(:get, "/"), "body", "text/plain", [])
      assert get_resp_header(conn, "cache-control") == ["no-store"]
    end
  end
end

defmodule Pax.AssetsLoggingTest do
  # Not async, since the test config only logs warnings and this needs info logs
  use ExUnit.Case, async: false

  import Plug.Test
  import ExUnit.CaptureLog

  setup do
    level = Logger.level()
    Logger.configure(level: :info)
    on_exit(fn -> Logger.configure(level: level) end)
  end

  defp call(conn, opts), do: Pax.Assets.call(conn, Pax.Assets.init(opts))

  test "can log requests" do
    log = capture_log(fn -> call(conn(:get, "/pax/assets/pax.css?vsn=1"), logging: true) end)
    assert log =~ "[Pax.Assets] GET /pax/assets/pax.css?vsn=1"

    log = capture_log(fn -> call(conn(:get, "/pax/assets/pax.js"), logging: true) end)
    assert log =~ "[Pax.Assets] GET /pax/assets/pax.js"
    refute log =~ "?"

    assert capture_log(fn -> call(conn(:get, "/pax/assets/pax.js"), []) end) == ""
  end
end
