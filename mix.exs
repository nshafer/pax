defmodule Pax.MixProject do
  use Mix.Project

  def project do
    [
      app: :pax,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Pax.Application, []}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:dev), do: ["lib", "dev"]
  # defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.19.0"},
      {:ecto, "~> 3.10"},
      # {:phoenix_ecto, "~> 4.4"},
      # {:phoenix_html, "~> 3.3"},
      {:gettext, "~> 0.20"},
      # {:jason, "~> 1.2"},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:esbuild, "~> 0.7", only: :dev, runtime: true},
      {:tailwind, "~> 0.2.0", only: :dev, runtime: true}
      # {:floki, ">= 0.30.0", only: :test},
      # {:ecto_sql, "~> 3.10", only: :test},
      # {:postgrex, ">= 0.0.0", only: :test},
    ]
  end

  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      # test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "tailwind reset", "esbuild.install --if-missing"],
      "assets.build": ["tailwind reset", "tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind reset", "tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
