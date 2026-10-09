defmodule Sandbox.Repo do
  # AshPostgres.Repo is a superset of Ecto.Repo, so the Ecto schemas and contexts in this app are unaffected by
  # it. It is here so Sandbox.Catalog's Ash resources can use the same database and the same tables.
  use AshPostgres.Repo,
    otp_app: :sandbox,
    # Those functions are installed by ash_postgres' migration generator, which this app does not run: the Ecto
    # migrations own the schema and every Ash resource sets `migrate? false`. Nothing here needs them.
    warn_on_missing_ash_functions?: false

  @impl AshPostgres.Repo
  def installed_extensions, do: []

  @impl AshPostgres.Repo
  def min_pg_version, do: Version.parse!("16.0.0")
end
