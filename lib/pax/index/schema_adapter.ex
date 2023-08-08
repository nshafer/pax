defmodule Pax.Index.SchemaAdapter do
  @behaviour Pax.Index.Adapter

  @impl Pax.Index.Adapter
  def init(_module, opts) do
    repo = Keyword.get(opts, :repo) || raise "repo is required"
    schema = Keyword.get(opts, :schema) || raise "schema is required"

    %{repo: repo, schema: schema}
  end

  @impl Pax.Index.Adapter
  def list_objects(_module, %{repo: repo, schema: schema}, _params, _uri, _socket) do
    repo.all(schema)
  end
end
