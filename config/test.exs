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

# The pagination plugin's page form has no id, which LiveViewTest warns about on every render
config :phoenix_live_view, :test_warnings, missing_form_id: :ignore
