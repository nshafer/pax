defmodule Mix.Tasks.Watch do
  use Mix.Task

  @impl Mix.Task
  def run(_) do
    tasks = [
      Task.async(Esbuild, :install_and_run, [:default, ~w(--sourcemap=inline --watch)]),
      Task.async(Tailwind, :install_and_run, [:default, ~w(--watch)])
    ]

    Task.await_many(tasks, :infinity)
  end
end
