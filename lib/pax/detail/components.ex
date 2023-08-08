defmodule Pax.Detail.Components do
  use Phoenix.Component

  attr(:fields, :list, required: true)
  attr(:object, :map, required: true)
  attr(:class, :string, default: nil)

  def detail(assigns) do
    ~H"""
    <div id="pax" class={["pax pax-detail", @class]}>
      <%= inspect(@object) %>
    </div>
    """
  end
end
