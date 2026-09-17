PaxTest.Owner.start()
{:ok, _} = Supervisor.start_link([PaxTest.Endpoint], strategy: :one_for_one)

# Tests tagged `:known_bug` describe the intended behavior of something that is currently broken. Run them with
# `mix test --only known_bug`.
ExUnit.start(exclude: [:known_bug])
