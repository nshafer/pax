defmodule Pax.Debug do
  defmacro dbg_m(ast, options \\ []) do
    options = Keyword.put_new(options, :header, format_dbg_m_header(__CALLER__))

    ast
    |> Macro.expand(__CALLER__)
    |> write_ast(options)

    ast
  end

  def write_ast(ast, options \\ []) do
    device = Keyword.get(options, :device, :stdio)
    header = Keyword.get(options, :header, nil)
    line_width = Keyword.get(options, :line_width, 80)
    syntax_colors = if IO.ANSI.enabled?(), do: IO.ANSI.syntax_colors(), else: []

    formatted =
      ast
      |> Code.quoted_to_algebra(syntax_colors: syntax_colors)
      |> Inspect.Algebra.format(line_width)

    ansidata =
      if header do
        ["[", :cyan, :italic, header, :reset, "]", "\n", formatted, "\n"]
      else
        [formatted, "\n"]
      end

    out = IO.ANSI.format(ansidata, syntax_colors != [])

    IO.write(device, out)
  end

  defp format_dbg_m_header(env) do
    env = Map.update!(env, :file, &(&1 && Path.relative_to_cwd(&1)))
    [stacktrace_entry] = Macro.Env.stacktrace(env)
    Exception.format_stacktrace_entry(stacktrace_entry)
  end
end
