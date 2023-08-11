defmodule Pax.Detail.Components do
  use Phoenix.Component

  attr(:fieldsets, :list, required: true)
  attr(:object, :map, required: true)
  attr(:class, :string, default: nil)

  def detail(assigns) do
    ~H"""
    <div id="pax" class={["pax pax-detail space-y-8", @class]}>
      <%= for {name, fields} <- @fieldsets do %>
        <Pax.Detail.Components.fieldset name={name} fields={fields} object={@object} />
      <% end %>
    </div>
    """
  end

  attr :name, :string, required: true
  attr :fields, :list, required: true
  attr :object, :map, required: true

  def fieldset(assigns) do
    ~H"""
    <div class="pax-fieldset">
      <h2
        :if={@name != :default}
        class={[
          "font-medium text-lg px-2 py-2 mb-2",
          "bg-neutral-200 dark:bg-neutral-800",
          "text-neutral-600 dark:text-neutral-400",
          "border-b border-b-neutral-300 dark: dark:border-b-neutral-700"
        ]}
      >
        <%= @name |> to_string() |> String.capitalize() %>
      </h2>
      <%= for row <- @fields do %>
        <div class={[
          "flex flex-col flex-wrap mb-2",
          "sm:flex-row sm:border-b sm:py-2 sm:mb-0 sm:gap-4"
        ]}>
          <%= for field <- row do %>
            <div class={[
              "flex-1 flex flex-col flex-nowrap mb-2 last:mb-0",
              "sm:flex-row sm:gap-x-4 sm:mb-0"
            ]}>
              <div class={[
                "font-semibold",
                "sm:w-32 sm:flex-shrink-0"
              ]}>
                <Pax.Field.Components.title field={field} />
              </div>
              <div class={[
                ""
              ]}>
                <Pax.Field.Components.display_as_text field={field} object={@object} />
              </div>
            </div>
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end
end
