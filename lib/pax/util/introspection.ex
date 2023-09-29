defmodule Pax.Util.Introspection do
  def field_name_to_label(name) when is_atom(name) do
    name
    |> Atom.to_string()
    |> String.slice(0..100)
    |> String.split(~r/[\W_]/)
    |> Enum.take(5)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> String.slice(0..25)
  end

  def name_from_struct(%{__struct__: struct_mod}) do
    name_from_struct(struct_mod)
  end

  def name_from_struct(struct_mod) when is_atom(struct_mod) do
    struct_mod
    |> Module.split()
    |> List.last()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
