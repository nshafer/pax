defmodule PaxTest.Repo do
  @moduledoc """
  A fake Ecto repo, so the library tests don't need a database.

  Every call is sent to the owning test as `{PaxTest.Repo, function, args}` so tests can assert on the queries that
  were built. Results come from stubs registered with `stub/2`, or sensible defaults:

    * `all/1` - `[]`
    * `one!/1` - raises `Ecto.NoResultsError`
    * `aggregate/2` - `0`
    * `insert/1` and `update/1` - apply the changeset, returning `{:error, changeset}` if it is invalid

  Real query behavior is exercised by the sandbox app's test suite against PostgreSQL.
  """

  alias PaxTest.Owner

  def stub(function, fun) when function in [:all, :one!, :aggregate, :insert, :update] do
    Owner.put({__MODULE__, function}, fun)
  end

  def all(query), do: call(:all, [query], fn _query -> [] end)

  def one!(query), do: call(:one!, [query], fn query -> raise Ecto.NoResultsError, queryable: query end)

  def aggregate(query, type), do: call(:aggregate, [query, type], fn _query, _type -> 0 end)

  def insert(changeset), do: call(:insert, [changeset], &Ecto.Changeset.apply_action(&1, :insert))

  def update(changeset), do: call(:update, [changeset], &Ecto.Changeset.apply_action(&1, :update))

  defp call(function, args, default) do
    Owner.notify({__MODULE__, function, args})
    fun = Owner.get({__MODULE__, function}, default)
    apply(fun, args)
  end
end
