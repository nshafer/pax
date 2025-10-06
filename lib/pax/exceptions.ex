defmodule Pax.ConfigError do
  defexception [:message]
end

defmodule Pax.Config.TypeError do
  defexception [:message, :types, :value]

  def exception(opts) do
    key = Keyword.fetch!(opts, :key)
    value = Keyword.fetch!(opts, :value)
    type = Keyword.get(opts, :type, :not_set)
    types = Keyword.get(opts, :types, :not_set)
    is_return = Keyword.get(opts, :is_return)

    preamble =
      if is_return do
        "invalid type returned from function for #{key}: #{inspect(value)}"
      else
        "invalid type given for #{key}: #{inspect(value)}"
      end

    msg =
      cond do
        type != :not_set ->
          "#{preamble}, should be #{explain_type(type)}"

        types != :not_set ->
          """
          #{preamble}

          Should be one of the following:
          - #{Enum.join(Enum.map(types, &explain_type/1), "\n- ")}
          """

        true ->
          preamble
      end

    %__MODULE__{message: msg, types: types, value: value}
  end

  defp explain_type(nil), do: "nil"
  defp explain_type(:atom), do: "an atom"
  defp explain_type(:string), do: "a string"
  defp explain_type(:boolean), do: "a boolean"
  defp explain_type(:integer), do: "an integer"
  defp explain_type(:float), do: "a float"
  defp explain_type(:tuple), do: "a tuple"
  defp explain_type(:list), do: "a list"
  defp explain_type(:map), do: "a map"
  defp explain_type(:module), do: "a module"
  defp explain_type(:struct), do: "a struct"
  defp explain_type({:struct, module}), do: "a #{module} struct"
  defp explain_type(:date), do: "a Date struct"
  defp explain_type(:time), do: "a Time struct"
  defp explain_type(:naive_datetime), do: "a NaiveDateTime struct"
  defp explain_type(:datetime), do: "a DateTime struct"
  defp explain_type(:uri), do: "a URI struct"
  defp explain_type(:function), do: "a function"
  defp explain_type({:function, arity}) when is_integer(arity), do: "a function with #{arity} arity"

  defp explain_type({:function, types}) when is_list(types) do
    "a function that returns #{Enum.join(Enum.map(types, &explain_type/1), " or ")}"
  end

  defp explain_type({:function, type}), do: "a function that returns #{explain_type(type)}"

  defp explain_type({:function, arity, types}) when is_integer(arity) and is_list(types) do
    "a function with #{arity} arity that returns #{Enum.join(Enum.map(types, &explain_type/1), " or ")}"
  end

  defp explain_type({:function, arity, type}) when is_integer(arity) do
    "a function with #{arity} arity that returns #{explain_type(type)}"
  end

  defp explain_type(type), do: "a #{inspect(type)}"
end

defmodule Pax.Config.SpecError do
  defexception [:message]
end

defmodule Pax.Config.ArityError do
  defexception [:message]
end

defmodule Pax.Assets.NotFoundError do
  defexception [:message, plug_status: 404]
end
