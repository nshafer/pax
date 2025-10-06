defmodule Pax.Util.Assets do
  require Logger

  @doc """
  Reads the contents of the file at the given path.

  If the file cannot be read, logs an error and returns an empty string.
  """
  def read(path) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, _} ->
        Logger.warning("Could not read asset at #{path}, did you forget to build it?")
        ""
    end
  end

  @doc """
  Stats the file at the given path.

  If the file cannot be read, logs an error and returns a `%File.Stat{}` with 0 size and times set to now.
  """
  def stat(path, opts \\ []) do
    case File.stat(path, opts) do
      {:ok, stat} ->
        stat

      {:error, _} ->
        Logger.warning("Could not stat asset at #{path}, did you forget to build it?")

        %File.Stat{
          size: 0,
          atime: System.system_time(:second),
          mtime: System.system_time(:second),
          ctime: System.system_time(:second)
        }
    end
  end

  @doc """
  Includes the contents of the file at the given path.

  The contents are wrapped in comments indicating the start and end of the included content. Source map URLs are also
  disabled by commenting them out.

  This is useful for embedding assets into a single file while retaining some level of traceability.
  """
  def include(path) do
    content =
      case File.read(path) do
        {:ok, content} ->
          String.replace(content, "//# sourceMappingURL=", "// ")

        {:error, _} ->
          Logger.error("Could not read asset at #{path}")
          "// Could not read asset at #{path}\n"
      end

    "//__BEGIN__ #{path}\n#{content}\n//__END__ #{path}\n"
  end

  @doc """
  Reads a JSON cache manifest from the given path.

  If the file cannot be read, returns an empty map. If a `key` is given, returns the value
  associated with that key in the manifest, or an empty map if the key does not exist. Example: "latest".
  """
  def read_cache_manifest(path, key \\ nil) do
    if File.exists?(path) do
      path
      |> File.read!()
      |> Phoenix.json_library().decode!()
      |> then(fn map -> if key, do: Map.get(map, key, %{}), else: map end)
    else
      %{}
    end
  end
end
