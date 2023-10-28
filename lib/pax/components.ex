defmodule Pax.Components do
  use Phoenix.Component

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
  Renders a header bar for use at the top of pages. Includes 5 sections that default in order left to right:

  1. leading: Left aligned, min-content - meant for action buttons or links
  2. title: Left aligned, 1/3 - meant for a title
  3. marquee: Center aligned, 1/3 - mean for a marquee element, such as a search bar
  4. actions: Right aligned, 1/3 - meant for actions, such as buttons and links
  5. trailing: Right aligned, min-content - meant for action buttons or links

  In addition, there is a repeatable :action slot for inserting multiple actions into the actions section, if it isn't
  overriden.
  """

  attr :pax, :map, required: true

  slot :leading
  slot :title, required: true
  slot :marquee
  slot :actions
  slot :trailing

  slot :action

  def pax_header(assigns) do
    ~H"""
    <div class="pax-header">
      <div :if={@leading != []} class="pax-header-leading">
        <%= render_slot(@leading) %>
      </div>

      <div class="pax-header-title">
        <%= render_slot(@title) %>
      </div>

      <div :if={@marquee != []} class="pax-header-marquee">
        <%= render_slot(@marquee) %>
      </div>

      <div class="pax-header-tools">
        <%= if @actions != [] do %>
          <%= render_slot(@actions) %>
        <% else %>
          <div :for={action <- @action} class="pax-header-tool">
            <%= render_slot(action) %>
          </div>
        <% end %>
      </div>

      <div :if={@trailing != []} class="pax-header-trailing">
        <%= render_slot(@trailing) %>
      </div>
    </div>
    """
  end
end
