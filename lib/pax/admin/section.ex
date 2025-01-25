defmodule Pax.Admin.Section do
  @derive {Phoenix.Param, key: :path}

  @type t() :: %__MODULE__{
          name: atom(),
          path: String.t(),
          label: String.t()
        }

  @enforce_keys [:name, :path, :label]
  defstruct [:name, :path, :label]
end
