defmodule Pax.Components do
  use Phoenix.Component

  @doc """
  Render components from plugins.

  You can define your own plugin component areas in your interface, then create plugins that implement those areas.

      <div>
      {plugin_component(:my_plugin_area, assigns)}
      </div>

  Then in your plugin, you can define a component that will be rendered in that area.

      defmodule MyPaxInterfacePlugin do
        use Phoenix.Component
        use Pax.Interface.Plugin

        def render_component(_opts, :my_plugin_area, assigns) do
          ~H\"""
          <div>{@pax.plural_name</div>
          \"""
        end
      end

  """
  def plugin_component(component, %{pax: pax} = assigns) do
    assigns = assign(assigns, :outputs, render_plugin_components(pax.plugins, component, assigns))

    ~H"""
    <%= for output <- @outputs do %>
      {output}
    <% end %>
    """
  end

  defp render_plugin_components(plugins, component, assigns) do
    for plugin <- plugins do
      apply(plugin.module, :render_component, [plugin.opts, component, assigns])
    end
  end

  @doc """
  Renders a title element with the given level. The level can be 1, 2 or 3. The default is 1.
  """
  @doc type: :component
  attr :level, :integer, values: [1, 2, 3], default: 1
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def pax_title(assigns) do
    ~H"""
    <div class={["pax-title", "pax-title-level-#{@level}", @class]} role="heading" aria-level={@level}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc """
  Renders a link using Phoenix.Component.link. All attributes from Phoenix.Component.link are passed through.
  """
  @doc type: :component
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(
    navigate patch href replace method csrf_token
    download hreflang referrerpolicy rel target type)
  slot :inner_block, required: true

  def pax_link(assigns) do
    ~H"""
    <Phoenix.Component.link class={["pax-link", @class]} {@rest}>
      {render_slot(@inner_block)}
    </Phoenix.Component.link>
    """
  end

  @doc """
  Renders a badge.
  """
  @doc type: :component
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(
    navigate patch href replace method csrf_token
    download hreflang referrerpolicy rel target type)
  slot :inner_block, required: true

  def pax_badge(assigns) do
    ~H"""
    <span class={["pax-badge", @class]} {@rest}>
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc """
  Renders a button. Can be called with "navigate", "patch" or "href" to render as a link styled like a button. All
  other attributes from Phoenix.Component.link are passed through in that case.

  ## Examples

      <.pax_button>Send!</.button>
      <.pax_button phx-click="go" class="ml-2">Send!</.button>
      <.pax_button navigate="/to/somewhere">Go somewhere</.button>
      <.pax_button patch="/my/liveview">Edit</.button>
  """
  @doc type: :component
  attr :type, :string, default: nil
  attr :class, :any, default: nil
  attr :secondary, :boolean, default: false
  attr :tertiary, :boolean, default: false
  attr :large, :boolean, default: false
  attr :icon, :boolean, default: false
  attr :rest, :global, include: ~w(
    disabled form name value
    navigate patch href replace method csrf_token
    download hreflang referrerpolicy rel target type)
  slot :inner_block, required: true

  def pax_button(assigns) do
    if assigns.rest[:navigate] != nil or assigns.rest[:patch] != nil or assigns.rest[:href] != nil do
      ~H"""
      <Phoenix.Component.link
        class={[
          "pax-button",
          @large && "pax-button-large",
          @icon && "pax-button-icon",
          @secondary && "pax-button-secondary",
          @tertiary && "pax-button-tertiary",
          @class
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </Phoenix.Component.link>
      """
    else
      ~H"""
      <button
        type={@type}
        class={[
          "pax-button",
          @large && "pax-button-large",
          @icon && "pax-button-icon",
          @secondary && "pax-button-secondary",
          @tertiary && "pax-button-tertiary",
          @class
        ]}
        {@rest}
      >
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders a simple select with no label.
  """
  @doc type: :component
  attr :id, :any, default: nil
  attr :name, :string
  attr :value, :any, required: true
  attr :class, :any, default: nil
  attr :options, :list, required: true, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :has_errors, :boolean, default: false
  attr :rest, :global, include: ~w(disabled form)

  def pax_select(assigns) do
    ~H"""
    <select id={@id} class={["pax-select", @has_errors && "has-errors", @class]} name={@name} multiple={@multiple} {@rest}>
      <option :if={@prompt} value="">{@prompt}</option>
      {Phoenix.HTML.Form.options_for_select(@options, @value)}
    </select>
    """
  end

  @doc """
  Renders a simple text input with no label.
  """
  @doc type: :component
  attr :id, :any, default: nil
  attr :name, :string
  attr :value, :any, required: true
  attr :class, :any, default: nil
  attr :has_errors, :boolean, default: false

  attr :type, :string,
    default: "text",
    values: ~w(color date datetime-local email file hidden month number password
               range radio search tel text time url week)

  attr :rest, :global, include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
               pattern placeholder readonly required size step inputmode)

  def pax_input(assigns) do
    ~H"""
    <input
      id={@id}
      class={["pax-input", @has_errors && "has-errors", @class]}
      type={@type}
      name={@name}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      {@rest}
    />
    """
  end

  @doc """
  Renders a header bar for use at the top of pages or sections. Includes 3 sections for content:

  1. primary: Aligned to the left side for desktops, useful for titles.
  2. secondary: Aligned to the right side for desktops, useful for links, buttons, etc.
  3. tertiary: Aligned in the middle for desktops, useful for search bars, etc.
  """
  @doc type: :component
  attr :class, :any, default: nil
  slot :primary
  slot :secondary
  slot :tertiary

  def pax_header(assigns) do
    ~H"""
    <div class={["pax-header", @class]}>
      <div class="pax-header-section pax-header-primary">
        {render_slot(@primary)}
      </div>

      <div class="pax-header-section pax-header-secondary">
        {render_slot(@secondary)}
      </div>

      <div class="pax-header-section pax-header-tertiary">
        {render_slot(@tertiary)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a footer bar for use at the bottom of pages or sections. Includes 3 sections for content:

  1. primary: Aligned to the left side for desktops, useful for status lines.
  2. secondary: Aligned to the right side for desktops, useful for links, buttons, etc.
  3. tertiary: Aligned in the middle for desktops.

  """
  @doc type: :component
  attr :class, :any, default: nil
  slot :primary
  slot :secondary
  slot :tertiary

  def pax_footer(assigns) do
    ~H"""
    <div class="pax-footer">
      <div class="pax-footer-section pax-footer-primary">
        {render_slot(@primary)}
      </div>

      <div class="pax-footer-section pax-footer-secondary">
        {render_slot(@secondary)}
      </div>

      <div class="pax-footer-section pax-footer-tertiary">
        {render_slot(@tertiary)}
      </div>
    </div>
    """
  end
end
