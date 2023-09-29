defmodule Pax.Field.Util do
  @doc """
  Sets the first fieldspec to have `link: true` if no fieldspec has a link option set.
  """
  @spec maybe_set_default_link_field([Pax.Field.fieldspec()]) :: [Pax.Field.fieldspec()]
  def maybe_set_default_link_field([]), do: []

  def maybe_set_default_link_field(fields) when is_list(fields) do
    has_link? =
      Enum.any?(fields, fn
        {_name, opts} when is_list(opts) -> Keyword.has_key?(opts, :link)
        {_name, _type, opts} -> Keyword.has_key?(opts, :link)
        _ -> false
      end)

    if has_link? do
      fields
    else
      [first_field | rest] = fields

      first_field =
        case first_field do
          name when is_atom(name) ->
            {name, link: true}

          {name, opts} when is_atom(name) and is_list(opts) ->
            {name, Keyword.put(opts, :link, true)}

          {name, type} when is_atom(name) and is_atom(type) ->
            {name, type, link: true}

          {name, type, opts} when is_atom(name) and is_atom(type) and is_list(opts) ->
            {name, type, Keyword.put(opts, :link, true)}
        end

      [first_field | rest]
    end
  end

  def maybe_set_default_link_field(arg), do: arg
end
