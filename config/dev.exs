import Config

# Configure esbuild (the version is required)
config :esbuild, version: "0.17.11"

# Compile the minimal pax.js file, which is included in other people's pages and should already have liveSocket
config :esbuild,
  pax: [
    args: ~w(js/pax.js --bundle --target=es2017 --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Compile the admin.js file, which assumes there is no other JS on the page, so initializes liveSocket
config :esbuild,
  admin: [
    args: ~w(js/admin.js --bundle --target=es2017 --outdir=../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind, version: "3.3.3"

# Compile the pax.css file. We use tailwind just for minifying, but there shouldn't be any tailwind in the output.
config :tailwind,
  pax: [
    args: ~w(--config=tailwind.pax.config.js --input=css/pax.css --output=../priv/static/pax.css),
    cd: Path.expand("../assets", __DIR__)
  ]

# Compile the admin.css file for use on all admin pages, which heavily uses tailwind.
config :tailwind,
  admin: [
    args: ~w(--config=tailwind.admin.config.js --input=css/admin.css --output=../priv/static/admin.css),
    cd: Path.expand("../assets", __DIR__)
  ]
