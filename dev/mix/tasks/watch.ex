defmodule Mix.Tasks.Watch do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    tasks = [
      Task.async(Esbuild, :install_and_run, [:pax, ~w(--sourcemap=inline --watch)]),
      Task.async(DartSass, :install_and_run, [:pax, ~w(--embed-source-map --watch)]),
      Task.async(Esbuild, :install_and_run, [:admin, ~w(--sourcemap=inline --watch)]),
      Task.async(DartSass, :install_and_run, [:admin, ~w(--embed-source-map --watch)])
    ]

    Task.await_many(tasks, :infinity)
  end
end
