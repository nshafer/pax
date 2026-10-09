defmodule Pax.Interface.LiveTest do
  use PaxTest.ConnCase, async: true

  # The lifecycle is plumbing that PhoenixTest doesn't expose (info messages, async results, hook replies), so
  # these tests drive the LiveView with Phoenix.LiveViewTest directly.
  import Phoenix.LiveViewTest, except: [open_browser: 1, open_browser: 2]

  alias Pax.Interface.Live
  alias Phoenix.LiveView.LiveStream

  defp index_interface(opts \\ []) do
    interface(
      Keyword.merge(
        [
          pax_plugins: [PaxTest.SpyPlugin],
          count_objects: fn _criteria, _socket -> 2 end,
          list_objects: fn _criteria, _socket -> [%{id: 1}, %{id: 2}] end
        ],
        opts
      )
    )
  end

  describe "mount" do
    test "calls pax_init/3 with the params and session, then initializes pax", %{conn: conn} do
      index_interface(
        pax_init: fn params, session, socket ->
          Owner.notify({:pax_init, params, session})
          {:cont, socket}
        end
      )

      {:ok, view, _html} = live(conn, "/interface?page=2")

      assert_receive {:pax_init, %{"page" => "2"}, %{}}
      assert_receive {:spy, :init, PaxTest.InterfaceLive, [halt: []]}
      assert has_element?(view, ".pax-index")
    end

    test "pax_init/3 can skip pax initialization without halting the mount", %{conn: conn} do
      index_interface(pax_init: fn _params, _session, socket -> {:skip, socket} end)

      {:ok, view, _html} = live(conn, "/interface")

      assert has_element?(view, "#no-pax")
      refute_received {:spy, :init, _, _}
      assert_received {:user_handle_params, _, _}
    end

    test "pax_init/3 can halt the mount with a redirect", %{conn: conn} do
      index_interface(
        pax_init: fn _params, _session, socket -> {:halt, Phoenix.LiveView.push_navigate(socket, to: "/elsewhere")} end,
        mount: fn _params, _session, _socket -> raise "should not mount" end
      )

      assert {:error, {:live_redirect, %{to: "/elsewhere"}}} = live(conn, "/interface")
      refute_received {:spy, :init, _, _}
    end

    test "pax_init/3 must redirect when halting", %{conn: conn} do
      index_interface(pax_init: fn _params, _session, socket -> {:halt, socket} end)

      assert_raise ArgumentError,
                   ~r/PaxTest.InterfaceLive.pax_init\/3 returned {:halt, socket} without redirecting/,
                   fn ->
                     live(conn, "/interface")
                   end
    end

    test "pax_init/3 must halt when redirecting", %{conn: conn} do
      for tag <- [:cont, :skip] do
        index_interface(
          pax_init: fn _params, _session, socket -> {tag, Phoenix.LiveView.push_navigate(socket, to: "/")} end
        )

        assert_raise ArgumentError, ~r/returned {#{inspect(tag)}, socket} after redirecting the socket/, fn ->
          live(conn, "/interface")
        end
      end
    end

    test "raises on an invalid pax_init/3 return", %{conn: conn} do
      index_interface(pax_init: fn _params, _session, socket -> {:ok, socket} end)

      assert_raise ArgumentError, ~r/Invalid return from PaxTest.InterfaceLive.pax_init\/3: {:ok, /, fn ->
        live(conn, "/interface")
      end
    end

    test "raises on invalid configuration", %{conn: conn} do
      index_interface(pax_config: [made_up: true])

      assert_raise Pax.ConfigError, "invalid key :made_up in config", fn -> live(conn, "/interface") end
    end
  end

  describe "handle_params" do
    test "assigns the global values before plugins run, and the action's values before after_params",
         %{conn: conn} do
      index_interface(pax_config: [plural_name: "Things"])

      {:ok, _view, _html} = live(conn, "/interface?page=2")

      assert_receive {:spy, :handle_params, %{"page" => "2"}, "http://www.example.com/interface?page=2", :index}
      assert_receive {:spy, :after_params, %Pax.Interface{plural_name: "Things", object_count: 2}}
      assert_receive {:user_handle_params, %{"page" => "2"}, _uri}
    end

    test "plugins can halt before the action runs", %{conn: conn} do
      index_interface(
        pax_plugins: [{PaxTest.SpyPlugin, halt: [:handle_params]}],
        count_objects: fn _, _ -> raise "should not count" end
      )

      {:ok, _view, _html} = live(conn, "/interface")

      assert_receive {:spy, :handle_params, _, _, :index}
      refute_received {:spy, :after_params, _}
      refute_received {:user_handle_params, _, _}
    end

    test "plugins can halt after params", %{conn: conn} do
      index_interface(pax_plugins: [{PaxTest.SpyPlugin, halt: [:after_params]}])

      {:ok, _view, _html} = live(conn, "/interface")

      assert_receive {:spy, :after_params, _}
      refute_received {:user_handle_params, _, _}
    end

    test "patching runs the chain again", %{conn: conn} do
      index_interface()
      {:ok, view, _html} = live(conn, "/interface")

      render_patch(view, "/interface?page=3")
      assert_receive {:spy, :handle_params, %{"page" => "3"}, _, :index}
      assert_receive {:user_handle_params, %{"page" => "3"}, _}
    end

    test "the delete action is not implemented", %{conn: conn} do
      index_interface()
      assert_raise RuntimeError, "Delete action not implemented", fn -> live(conn, "/interface/1/delete") end
    end

    test "other actions only run the global and plugin steps", %{conn: conn} do
      index_interface(count_objects: fn _, _ -> raise "should not count" end)

      {:ok, view, _html} = live(conn, "/interface/1/other")

      assert_receive {:spy, :after_params, %Pax.Interface{action: :other}}
      assert has_element?(view, ".pax-interface")
      refute has_element?(view, ".pax-index")
    end
  end

  describe "handle_event" do
    test "plugins get events before the LiveView", %{conn: conn} do
      index_interface()
      {:ok, view, _html} = live(conn, "/interface")

      render_click(view, "custom", %{"a" => "1"})

      assert_receive {:spy, :handle_event, "custom", %{"a" => "1"}}
      assert_receive {:user_handle_event, "custom", %{"a" => "1"}}
    end

    test "plugins can halt events", %{conn: conn} do
      index_interface(pax_plugins: [{PaxTest.SpyPlugin, halt: [:handle_event]}])
      {:ok, view, _html} = live(conn, "/interface")

      render_click(view, "custom", %{})

      assert_receive {:spy, :handle_event, "custom", _}
      refute_received {:user_handle_event, "custom", _}
    end

    test "plugins can halt events with a reply", %{conn: conn} do
      index_interface()
      {:ok, view, _html} = live(conn, "/interface")

      render_hook(view, "spy_reply", %{"a" => "1"})

      assert_reply(view, %{replied: true})
      refute_received {:user_handle_event, "spy_reply", _}
    end

    test "detail actions get events before plugins", %{conn: conn} do
      interface(
        pax_plugins: [PaxTest.SpyPlugin],
        pax_config: [fields: [{:name, :string}]],
        get_object: fn _, _, _ -> %PaxTest.Author{id: 1, name: "Ursula"} end,
        change_object: fn object, _ -> PaxTest.Author.changeset(object, %{}) end,
        validate_object: fn object, _, params, _ -> PaxTest.Author.changeset(object, params) end
      )

      {:ok, view, _html} = live(conn, "/interface/1/edit")
      render_change(view, "pax_validate", %{"detail" => %{"name" => ""}})
      refute_received {:spy, :handle_event, "pax_validate", _}

      render_click(view, "other", %{})
      assert_receive {:spy, :handle_event, "other", _}

      {:ok, view, _html} = live(conn, "/interface/1")
      render_click(view, "other", %{})
      assert_receive {:spy, :handle_event, "other", _}
    end
  end

  describe "handle_info" do
    test "plugins get messages before the LiveView", %{conn: conn} do
      index_interface()
      {:ok, view, _html} = live(conn, "/interface")

      send(view.pid, :ping)
      render(view)

      assert_receive {:spy, :handle_info, :ping}
      assert_receive {:user_handle_info, :ping}
    end

    test "plugins can halt messages", %{conn: conn} do
      index_interface(pax_plugins: [{PaxTest.SpyPlugin, halt: [:handle_info]}])
      {:ok, view, _html} = live(conn, "/interface")

      send(view.pid, :ping)
      render(view)

      assert_receive {:spy, :handle_info, :ping}
      refute_received {:user_handle_info, :ping}
    end
  end

  describe "handle_async" do
    test "plugins get async results before the LiveView", %{conn: conn} do
      index_interface()
      {:ok, view, _html} = live(conn, "/interface")

      render_click(view, "start_async", %{"result" => "done"})
      render_async(view)

      assert_receive {:spy, :handle_async, :test_task, {:ok, "done"}}
      assert_receive {:user_handle_async, :test_task, {:ok, "done"}}
    end

    test "plugins can halt async results", %{conn: conn} do
      index_interface(pax_plugins: [{PaxTest.SpyPlugin, halt: [:handle_async]}])
      {:ok, view, _html} = live(conn, "/interface")

      render_click(view, "start_async", %{"result" => "done"})
      render_async(view)

      assert_receive {:spy, :handle_async, :test_task, {:ok, "done"}}
      refute_received {:user_handle_async, :test_task, _}
    end
  end

  describe "after_render" do
    test "prunes the objects stream on the index before plugins run", %{conn: conn} do
      index_interface()
      {:ok, _view, _html} = live(conn, "/interface")

      assert_receive {:spy, :after_render, %Pax.Interface{action: :index, objects: %LiveStream{inserts: []}}}
    end

    test "runs for other actions", %{conn: conn} do
      index_interface()
      {:ok, _view, _html} = live(conn, "/interface/1/other")

      assert_receive {:spy, :after_render, %Pax.Interface{action: :other}}
    end
  end

  # These dispatchers and action callbacks are public, but not currently called by the lifecycle
  describe "unused action callbacks" do
    defp socket(action), do: %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}, pax: %Pax.Interface{action: action}}}

    test "action_handle_info/2 and action_handle_async/3 continue for every action" do
      for action <- [:index, :new, :show, :edit, :other] do
        socket = socket(action)

        assert Live.action_handle_info(:msg, socket) == {:cont, socket}
        assert Live.action_handle_async(:name, {:ok, :result}, socket) == {:cont, socket}
      end
    end

    test "Index and Detail ignore events, messages and async results they don't handle" do
      socket = socket(:index)

      assert Pax.Interface.Index.handle_event("event", %{}, socket) == {:cont, socket}
      assert Pax.Interface.Detail.handle_event("pax_validate", %{"not_detail" => %{}}, socket) == {:cont, socket}
      assert Pax.Interface.Detail.after_render(socket) == socket
    end

    test "clear_objects_stream/1 leaves non-stream objects alone" do
      socket = socket(:index)
      assert Pax.Interface.Index.clear_objects_stream(socket) == socket
    end
  end
end
