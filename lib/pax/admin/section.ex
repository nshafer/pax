defmodule Pax.Admin.Section do
  @type t() :: %__MODULE__{
          name: atom(),
          path: String.t(),
          title: String.t()
        }

  @enforce_keys [:name, :path, :title]
  defstruct [:name, :path, :title]
end
