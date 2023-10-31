import Config

# Configure esbuild (the version is required)
config :esbuild, version: "0.19.5"

# Compile the minimal pax.js file, which is included in other people's pages and should already have liveSocket
config :esbuild,
  pax: [
    args: ~w(js/pax.js --bundle --target=es2017 --outdir=../../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets/pax", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Compile the admin.js file, which assumes there is no other JS on the page, so initializes liveSocket
config :esbuild,
  admin: [
    args: ~w(js/admin.js --bundle --target=es2017 --outdir=../../priv/static --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets/admin", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure dart_sass (the version is required)
config :dart_sass, version: "1.69.5"

# Compile the pax.css file, which is minimal styling for pax interfaces.
config :dart_sass,
  pax: [
    args: ~w(--load-path=. css/pax.scss ../../priv/static/pax.css),
    cd: Path.expand("../assets/pax", __DIR__)
  ]

# Compile the admin.css file for use on all admin pages.
config :dart_sass,
  admin: [
    args: ~w(--load-path=. css/admin.scss ../../priv/static/admin.css),
    cd: Path.expand("../assets/admin", __DIR__)
  ]
