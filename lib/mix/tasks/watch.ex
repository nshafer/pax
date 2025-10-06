defmodule Mix.Tasks.Watch do
  @moduledoc """
  Watches and rebuilds Pax assets (JS and CSS) in dev mode.

  This is not intended to be run by users of the Pax library. It is only useful when developing Pax itself.
  """

  use Mix.Task

  @shortdoc "Watches and rebuilds Pax assets (JS and CSS) in dev mode"

  @impl Mix.Task
  def run(_) do
    tasks = [
      Task.async(Esbuild, :install_and_run, [:pax, ~w(--sourcemap=inline --watch)]),
      Task.async(DartSass, :install_and_run, [:pax, ~w(--embed-source-map --watch)]),
      Task.async(Esbuild, :install_and_run, [:pax_admin, ~w(--sourcemap=inline --watch)]),
      Task.async(DartSass, :install_and_run, [:pax_admin, ~w(--embed-source-map --watch)])
    ]

    Task.await_many(tasks, :infinity)
  end
end
