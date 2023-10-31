defmodule Pax.Components do
  use Phoenix.Component

  attr :level, :integer, values: [1, 2, 3], default: 1
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def pax_title(assigns) do
    ~H"""
    <div class={["pax-title", "pax-title-level-#{@level}", @class]} @rest>
      <%= render_slot(@inner_block) %>
    </div>
    """
  end

  @doc """
  Renders a link using Phoenix.Component.link. All attributes from Phoenix.Component.link are passed through.
  """

  attr :class, :any, default: nil

  attr :rest, :global, include: ~w(
    navigate patch href replace method csrf_token
    download hreflang referrerpolicy rel target type)

  slot :inner_block, required: true

  def pax_link(assigns) do
    ~H"""
    <Phoenix.Component.link class={["pax-link", @class]} {@rest}>
      <%= render_slot(@inner_block) %>
    </Phoenix.Component.link>
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
          @class
        ]}
        {@rest}
      >
        <%= render_slot(@inner_block) %>
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
          @class
        ]}
        {@rest}
      >
        <%= render_slot(@inner_block) %>
      </button>
      """
    end
  end

  @doc """
  Renders a header bar for use at the top of pages or sections. Includes 3 sections for content:

  1. primary: Aligned to the left side by default, useful for titles.
  2. secondary: Aligned to the right side by default, useful for links, tools, actions, etc.
  3. tertiary: Aligned in the middle by default, useful for search bars, etc.
  """

  slot :primary
  slot :secondary
  slot :tertiary

  def pax_header(assigns) do
    ~H"""
    <div class="pax-header">
      <div :if={@primary != []} class="pax-header-primary">
        <%= render_slot(@primary) %>
      </div>

      <div :if={@secondary != []} class="pax-header-secondary">
        <%= render_slot(@secondary) %>
      </div>

      <div :if={@tertiary != []} class="pax-header-tertiary">
        <%= render_slot(@tertiary) %>
      </div>
    </div>
    """
  end

  slot :action

  def pax_actions(assigns) do
    ~H"""
    <div class="pax-actions">
      <div :for={action <- @action} class="pax-actions-item">
        <%= render_slot(action) %>
      </div>
    </div>
    """
  end
end
