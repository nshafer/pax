import Config

config :pax, PaxTest.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "pax-test-secret-key-base-pax-test-secret-key-base-pax-test-secret-key-base",
  live_view: [signing_salt: "pax-test-signing-salt"],
  render_errors: [formats: [html: PaxTest.ErrorHTML], layout: false],
  server: false

config :phoenix_test, :endpoint, PaxTest.Endpoint

config :logger, level: :warning

# Initialize plugs at runtime, so the test endpoint can compile before the test router
config :phoenix, :plug_init_mode, :runtime

# Ash is an optional dependency, compiled here so Pax.Adapters.Ash can be built and tested. Ash 3.33 requires
# this to be set explicitly whenever a resource has a string attribute.
config :ash, default_string_length_count: :codepoints
