defmodule Pax.Util.Introspection do
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
