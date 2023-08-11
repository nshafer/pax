defmodule Mix.Tasks.Watch do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    tasks = [
      Task.async(Esbuild, :install_and_run, [:pax, ~w(--sourcemap=inline --watch)]),
      Task.async(Tailwind, :install_and_run, [:pax, ~w(--watch)]),
      Task.async(Esbuild, :install_and_run, [:admin, ~w(--sourcemap=inline --watch)]),
      Task.async(Tailwind, :install_and_run, [:admin, ~w(--watch)])
    ]

    Task.await_many(tasks, :infinity)
  end
end
