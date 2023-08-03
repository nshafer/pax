import Config

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/pax.js --bundle --target=es2017 --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.3",
  default: [
    args: ~w(--config=tailwind.config.js --input=css/pax.css --output=../priv/static/pax.css),
    cd: Path.expand("../assets", __DIR__)
  ]
