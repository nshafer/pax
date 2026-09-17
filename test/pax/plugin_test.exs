defmodule Pax.PluginTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2]
  import PaxTest.HTML
  alias Pax.Plugin

  defmodule HelloPlugin do
    use Pax.Interface.Plugin
    use Phoenix.Component

    def init(_callback_module, opts), do: %{greeting: Keyword.get(opts, :greeting, "Hello")}
    def config_key, do: :hello

    def render(opts, :greet, assigns) do
      assigns = assign(assigns, :greeting, opts.greeting)

      ~H"""
      <p>{@greeting} {@pax.singular_name}</p>
      """
    end

    def render(_opts, _section, _assigns), do: nil
  end

  # `use Pax.Interface.Plugin` always defines `type/0` as `:interface`, so plugins with an invalid type can only be
  # defined by implementing the callbacks directly
  defmodule BadTypePlugin do
    def type, do: "interface"
  end

  defmodule NilTypePlugin do
    def type, do: nil
  end

  defmodule BadConfigKeyPlugin do
    def type, do: :interface
    def config_key, do: "key"
  end

  defmodule BadInitPlugin do
    def type, do: :interface
    def config_key, do: nil
    def init(_callback_module, opts), do: opts
  end

  describe "init/2" do
    test "initializes a plugin module without opts" do
      assert Plugin.init(:callback, HelloPlugin) == %Plugin{
               module: HelloPlugin,
               type: :interface,
               config_key: :hello,
               opts: %{greeting: "Hello"}
             }
    end

    test "initializes a plugin module with opts" do
      assert %Plugin{opts: %{greeting: "Hi"}} = Plugin.init(:callback, {HelloPlugin, greeting: "Hi"})
    end

    test "passes the callback module to the plugin" do
      Plugin.init(PaxTest.InterfaceLive, {PaxTest.SpyPlugin, halt: []})
      assert_received {:spy, :init, PaxTest.InterfaceLive, [halt: []]}
    end

    test "raises on an invalid type" do
      assert_raise ArgumentError, ~r/Invalid plugin type returned from Pax.PluginTest.BadTypePlugin.type\/0/, fn ->
        Plugin.init(:callback, BadTypePlugin)
      end

      assert_raise ArgumentError, ~r/Invalid plugin type/, fn -> Plugin.init(:callback, NilTypePlugin) end
    end

    test "raises on an invalid config key" do
      assert_raise ArgumentError, ~r/Invalid config key returned from Pax.PluginTest.BadConfigKeyPlugin/, fn ->
        Plugin.init(:callback, BadConfigKeyPlugin)
      end
    end

    test "raises when init doesn't return a map" do
      assert_raise ArgumentError, ~r/Invalid plugin opts returned from Pax.PluginTest.BadInitPlugin.init\/2/, fn ->
        Plugin.init(:callback, {BadInitPlugin, [a: 1]})
      end
    end
  end

  describe "config functions" do
    test "delegate to the plugin module" do
      plugin = Plugin.init(:callback, PaxTest.SpyPlugin)

      assert Plugin.config_key(plugin) == :spy
      assert Plugin.config_spec(plugin) == %{label: [:string, {:function, 1, :string}]}
      assert %Plugin{opts: %{label: "spy"}} = Plugin.merge_config(plugin, %{}, :socket)
    end
  end

  describe "use Pax.Interface.Plugin" do
    test "provides defaults for every callback" do
      assert PaxTest.BarePlugin.type() == :interface
      assert PaxTest.BarePlugin.init(:callback, a: 1) == %{}
      assert PaxTest.BarePlugin.config_key() == nil
      assert PaxTest.BarePlugin.config_spec() == %{}
      assert PaxTest.BarePlugin.merge_config(%{a: 1}, %{}, :socket) == %{}
      assert PaxTest.BarePlugin.render(%{}, :index_body, %{}) == nil
    end
  end

  describe "render/2" do
    setup do
      plugins = [
        Plugin.init(:callback, HelloPlugin),
        Plugin.init(:callback, PaxTest.BarePlugin),
        Plugin.init(:callback, {HelloPlugin, greeting: "Hi"})
      ]

      %{pax: %Pax.Interface{plugins: plugins, singular_name: "Book"}}
    end

    test "renders every plugin's section in order", %{pax: pax} do
      assigns = %{__changed__: %{}, pax: pax}

      html = ~H"""
      <div>{Plugin.render(:greet, assigns)}</div>
      """

      assert texts(html, "p") == ["Hello Book", "Hi Book"]
    end

    test "renders nothing when no plugin renders the section", %{pax: pax} do
      assigns = %{pax: pax}

      html = ~H"""
      <div>{Plugin.render(:other, assigns)}</div>
      """

      assert text(html, "div") == ""
    end

    test "fingerprints by section and plugins", %{pax: pax} do
      assigns = %{pax: pax}

      assert Plugin.render(:greet, assigns).fingerprint == Plugin.render(:greet, assigns).fingerprint
      refute Plugin.render(:greet, assigns).fingerprint == Plugin.render(:other, assigns).fingerprint

      other_assigns = %{pax: %{pax | plugins: tl(pax.plugins)}}
      refute Plugin.render(:greet, assigns).fingerprint == Plugin.render(:greet, other_assigns).fingerprint
    end
  end
end
