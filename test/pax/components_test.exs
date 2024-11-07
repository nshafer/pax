defmodule Pax.ComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component
  import Phoenix.LiveViewTest

  import Pax.Components

  test "render title" do
    assigns = %{}

    r = ~H"""
    <.pax_title>Test</.pax_title>
    """

    assert rendered_to_string(r) =~ ~S[class="pax-title pax-title-level-1"]
    assert rendered_to_string(r) =~ ~S[pax-title]
    assert rendered_to_string(r) =~ ~S[role="heading"]
    assert rendered_to_string(r) =~ ~S[aria-level="1"]
  end
end
