defmodule PaxTest.HTML do
  @moduledoc """
  Helpers for asserting on rendered components without a LiveView.
  """

  @doc "Render a component, rendered struct or string to an HTML string."
  def to_html(%Phoenix.LiveView.Rendered{} = rendered), do: Phoenix.LiveViewTest.rendered_to_string(rendered)
  def to_html(nil), do: ""
  def to_html(string) when is_binary(string), do: string

  @doc "Render and parse HTML as a fragment."
  def parse(%LazyHTML{} = html), do: html
  def parse(rendered), do: rendered |> to_html() |> LazyHTML.from_fragment()

  @doc "The whitespace-normalized text of every element matching `selector`."
  def text(rendered, selector) do
    rendered
    |> parse()
    |> LazyHTML.query(selector)
    |> LazyHTML.text()
    |> squish()
  end

  @doc "The whitespace-normalized text of each element matching `selector`."
  def texts(rendered, selector) do
    rendered
    |> parse()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> squish()))
  end

  @doc "The values of `name` on every element matching `selector`."
  def attr(rendered, selector, name) do
    rendered
    |> parse()
    |> LazyHTML.query(selector)
    |> LazyHTML.attribute(name)
  end

  @doc "The class names of each element matching `selector`, ignoring extra whitespace."
  def classes(rendered, selector) do
    rendered
    |> attr(selector, "class")
    |> Enum.map(&squish/1)
  end

  @doc "The number of elements matching `selector`."
  def count(rendered, selector) do
    rendered
    |> parse()
    |> LazyHTML.query(selector)
    |> Enum.count()
  end

  @doc "Collapse runs of whitespace into single spaces."
  def squish(string), do: string |> String.split() |> Enum.join(" ")
end

defmodule PaxTest.PluginHelpers do
  @moduledoc """
  Helpers for testing plugins outside of a LiveView.
  """

  @doc "Initialize a plugin and merge validated `config` into it, as `Pax.Interface.Live` does."
  def plugin(module, init_opts \\ [], config \\ [], socket \\ nil) do
    plugin = Pax.Plugin.init(PaxTest.InterfaceLive, {module, init_opts})
    config = Pax.Config.validate!(module.config_spec(), config, validate_config_spec: true)
    Pax.Plugin.merge_config(plugin, config, socket)
  end

  @doc "Render a plugin's `section` with `pax` as the `@pax` assign, returning an HTML string."
  def render_plugin(%Pax.Plugin{} = plugin, section, %Pax.Interface{} = pax) do
    plugin.opts
    |> plugin.module.render(section, %{__changed__: nil, pax: pax})
    |> PaxTest.HTML.to_html()
  end
end
