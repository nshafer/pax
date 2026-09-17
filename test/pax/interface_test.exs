defmodule Pax.InterfaceTest do
  use ExUnit.Case, async: true

  import Pax.Interface

  defp build(:socket, assigns), do: %Phoenix.LiveView.Socket{assigns: Map.merge(%{__changed__: %{}}, assigns)}
  defp build(:assigns, assigns), do: Map.merge(%{__changed__: %{}}, assigns)

  # Every helper accepts either a socket or an assigns map, so run each test against both
  for kind <- [:socket, :assigns] do
    @kind kind

    describe "#{kind}" do
      test "assign_pax/3 creates the struct and assigns into it" do
        result = assign_pax(build(@kind, %{}), :singular_name, "Book")

        assert %Pax.Interface{singular_name: "Book"} = get_pax(result)
        assert result_changed?(result)
      end

      test "assign_pax/3 keeps existing values" do
        result = build(@kind, %{pax: %Pax.Interface{plural_name: "Books"}}) |> assign_pax(:singular_name, "Book")

        assert %Pax.Interface{singular_name: "Book", plural_name: "Books"} = get_pax(result)
      end

      test "assign_pax/2 assigns a keyword list or map" do
        result = assign_pax(build(@kind, %{}), singular_name: "Book", plural_name: "Books")
        assert %Pax.Interface{singular_name: "Book", plural_name: "Books"} = get_pax(result)

        result = assign_pax(build(@kind, %{}), %{action: :index})
        assert %Pax.Interface{action: :index} = get_pax(result)
      end

      test "assign_pax/3 raises on unknown keys" do
        assert_raise KeyError, fn -> assign_pax(build(@kind, %{}), :nope, 1) end
      end

      test "ensure_pax_private/2 adds an empty map for the prefix without replacing an existing one" do
        result = ensure_pax_private(build(@kind, %{}), :plugin)
        assert get_pax(result).private == %{plugin: %{}}

        result = build(@kind, %{pax: %Pax.Interface{private: %{plugin: %{a: 1}}}}) |> ensure_pax_private(:plugin)
        assert get_pax(result).private == %{plugin: %{a: 1}}
      end

      test "assign_pax_private/4 assigns under the prefix" do
        result =
          build(@kind, %{pax: %Pax.Interface{private: %{other: %{b: 2}}}})
          |> assign_pax_private(:plugin, :a, 1)
          |> assign_pax_private(:plugin, :c, 3)

        assert get_pax(result).private == %{other: %{b: 2}, plugin: %{a: 1, c: 3}}
      end

      test "assign_pax_private/3 assigns a keyword list or map under the prefix" do
        result = assign_pax_private(build(@kind, %{}), :plugin, a: 1, b: 2)
        assert get_pax(result).private == %{plugin: %{a: 1, b: 2}}

        result = assign_pax_private(build(@kind, %{}), :plugin, %{a: 1})
        assert get_pax(result).private == %{plugin: %{a: 1}}
      end

      test "assign_pax_criteria/3 assigns into the criteria" do
        result =
          build(@kind, %{pax: %Pax.Interface{criteria: %{limit: 10}}})
          |> assign_pax_criteria(:offset, 20)

        assert get_pax(result).criteria == %{limit: 10, offset: 20}
      end

      test "assign_pax_criteria/2 assigns a keyword list or map" do
        result = assign_pax_criteria(build(@kind, %{}), limit: 10, offset: 0)
        assert get_pax(result).criteria == %{limit: 10, offset: 0}

        result = assign_pax_criteria(build(@kind, %{}), %{order_by: :name})
        assert get_pax(result).criteria == %{order_by: :name}
      end
    end
  end

  defp get_pax(%Phoenix.LiveView.Socket{assigns: assigns}), do: assigns.pax
  defp get_pax(assigns), do: assigns.pax

  defp result_changed?(%Phoenix.LiveView.Socket{assigns: assigns}), do: Map.has_key?(assigns.__changed__, :pax)
  defp result_changed?(assigns), do: Map.has_key?(assigns.__changed__, :pax)
end
