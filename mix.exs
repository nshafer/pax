defmodule Pax.MixProject do
  use Mix.Project

  def project do
    [
      app: :pax,
      version: "0.0.1-dev",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "Pax",
      description: description(),
      source_url: "https://github.com/nshafer/pax",
      package: package(),
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
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def description() do
    "Toolkit for live CRUD applications and admins"
  end

  def package() do
    [
      name: "pax",
      files: ~w(lib priv .formatter.exs mix.exs README* LICENSE*),
      exclude_patterns: ~w(lib/mix/tasks/watch.ex),
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/nshafer/pax"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.8"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_live_view, "~> 1.0"},
      {:ecto, "~> 3.10"},
      {:gettext, "~> 0.26.0 or ~> 1.0.0"},
      {:jason, "~> 1.2", only: [:dev, :test]},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:esbuild, "~> 0.9", only: :dev},
      {:dart_sass, "~> 0.7", only: :dev},
      {:phoenix_copy, "~> 0.1", only: :dev},
      # {:floki, ">= 0.30.0", only: :test},
      {:ecto_sql, "~> 3.10", only: [:dev, :test]}
      # {:postgrex, ">= 0.0.0", only: :test},
    ]
  end

  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      # test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      build: ["assets.deploy", "hex.build"],
      "assets.setup": ["sass.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["assets.build.pax", "assets.build.pax_admin"],
      "assets.build.pax": ["sass pax --embed-source-map", "esbuild pax"],
      "assets.build.pax_admin": ["sass pax_admin --embed-source-map", "esbuild pax_admin"],
      "assets.deploy": ["assets.deploy.pax", "assets.deploy.pax_admin"],
      "assets.deploy.pax": ["sass pax --no-source-map --style=compressed", "esbuild pax --minify"],
      "assets.deploy.pax_admin": ["sass pax_admin --no-source-map --style=compressed", "esbuild pax_admin --minify"],
      package: ["assets.deploy", "phx.digest"],
      "build.unpack": ["package", "hex.build --unpack"],
      clean: ["clean", "phx.digest.clean --all"]
    ]
  end
end
