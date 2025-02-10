defmodule Pax.Util.String do
  @spec truncate(String.t() | nil, integer()) :: String.t()
  def truncate(nil, _length), do: nil

  def truncate(string, length) when is_binary(string) and is_integer(length) do
    if String.length(string) > length do
      string
      |> String.slice(0, length - 1)
      |> Kernel.<>("…")
    else
      string
    end
  end
end
