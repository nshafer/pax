defmodule Pax.MixProject do
  use Mix.Project

  def project do
    [
      app: :pax,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      name: "Pax",
      description: description(),
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
    "A toolkit for rapibly building Live View interfaces for CRUD operations."
  end

  def package() do
    [
      name: "pax",
      files: ~w(lib/pax* priv .formatter.exs mix.exs README.md),
      licenses: ["Apache-2.0"],
      links: %{
        "GitHub" => "https://github.com/nshafer/pax"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_live_view, "~> 0.19.0"},
      {:ecto, "~> 3.10"},
      # {:phoenix_ecto, "~> 4.4"},
      # {:phoenix_html, "~> 3.3"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2", only: :dev},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:esbuild, "~> 0.7", only: :dev},
      {:tailwind, "~> 0.2.0", only: :dev},
      {:phoenix_copy, "~> 0.1.3", only: :dev}
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
      build: ["assets.deploy", "hex.build"],
      "build.unpack": ["assets.deploy", "hex.build --unpack"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["assets.build.pax", "assets.build.admin"],
      "assets.build.pax": ["tailwind pax", "esbuild pax"],
      "assets.build.admin": ["tailwind admin", "esbuild admin"],
      "assets.deploy": ["assets.deploy.pax", "assets.deploy.admin"],
      "assets.deploy.pax": ["tailwind pax --minify", "esbuild pax --minify"],
      "assets.deploy.admin": ["tailwind admin --minify", "esbuild admin --minify"]
    ]
  end
end
