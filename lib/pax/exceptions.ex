defmodule Pax.ConfigError do
  defexception [:message]
end

defmodule Pax.Config.TypeError do
  defexception [:message]
end

defmodule Pax.Config.SpecError do
  defexception [:message]
end

defmodule Pax.Config.ArityError do
  defexception [:message]
end
