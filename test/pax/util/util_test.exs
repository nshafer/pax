defmodule Pax.Util.StringTest do
  use ExUnit.Case, async: true

  import Pax.Util.String

  describe "truncate/2" do
    test "returns nil for nil" do
      assert truncate(nil, 10) == nil
    end

    test "leaves strings at or under the length alone" do
      assert truncate("", 5) == ""
      assert truncate("hello", 10) == "hello"
      assert truncate("hello", 5) == "hello"
    end

    test "truncates longer strings to the length, including an ellipsis" do
      assert truncate("hello world", 5) == "hell…"
      assert String.length(truncate("hello world", 5)) == 5
    end

    test "counts graphemes, not bytes" do
      assert truncate("héllo", 5) == "héllo"
      assert truncate("héllo wörld", 3) == "hé…"
    end
  end
end

defmodule Pax.Util.InflectionTest do
  use ExUnit.Case, async: true

  alias Pax.Util.Inflection

  describe "pluralize/1" do
    test "appends an s" do
      assert Inflection.pluralize("Book") == "Books"
      assert Inflection.pluralize("Album") == "Albums"
    end
  end
end

defmodule Pax.Util.IntrospectionTest do
  use ExUnit.Case, async: true

  alias Pax.Util.Introspection

  describe "field_name_to_label/1" do
    test "capitalizes each word of an atom or string" do
      assert Introspection.field_name_to_label(:name) == "Name"
      assert Introspection.field_name_to_label(:first_name) == "First Name"
      assert Introspection.field_name_to_label("first_name") == "First Name"
    end

    test "splits on any non-word character" do
      assert Introspection.field_name_to_label("first-name.last name") == "First Name Last Name"
    end

    test "limits the label to 5 words and 26 characters" do
      assert Introspection.field_name_to_label(:a_b_c_d_e_f_g) == "A B C D E"
      assert Introspection.field_name_to_label(:abcdefghijklmnopqrstuvwxyz_abcdefg) == "Abcdefghijklmnopqrstuvwxyz"
    end
  end

  describe "name_from_struct/1" do
    test "uses the last part of the module name" do
      assert Introspection.name_from_struct(PaxTest.Book) == "Book"
      assert Introspection.name_from_struct(%PaxTest.Book{}) == "Book"
    end

    test "only capitalizes the first letter" do
      assert Introspection.name_from_struct(PaxTest.AllTypes) == "Alltypes"
    end
  end

  describe "resource_name_to_label/1" do
    test "capitalizes each word of an atom or string" do
      assert Introspection.resource_name_to_label(:record_labels) == "Record Labels"
      assert Introspection.resource_name_to_label("record-labels") == "Record Labels"
    end

    test "limits the label to 5 words and 26 characters" do
      assert Introspection.resource_name_to_label(:a_b_c_d_e_f_g) == "A B C D E"

      assert Introspection.resource_name_to_label(String.duplicate("a", 40)) ==
               String.capitalize(String.duplicate("a", 26))
    end
  end
end

defmodule Pax.Util.AssetsTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog
  alias Pax.Util.Assets

  @moduletag :tmp_dir

  describe "read/1" do
    test "returns the contents of the file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "app.css")
      File.write!(path, "body {}")

      assert Assets.read(path) == "body {}"
    end

    test "logs a warning and returns an empty string when the file is missing", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing.css")

      log = capture_log(fn -> assert Assets.read(path) == "" end)
      assert log =~ "Could not read asset at #{path}, did you forget to build it?"
    end
  end

  describe "stat/2" do
    test "returns the file's stat", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "app.css")
      File.write!(path, "body {}")

      assert %File.Stat{size: 7, mtime: mtime} = Assets.stat(path, time: :posix)
      assert is_integer(mtime)
    end

    test "logs a warning and returns an empty stat with the current time when the file is missing",
         %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing.css")
      now = System.system_time(:second)

      log = capture_log(fn -> send(self(), {:stat, Assets.stat(path)}) end)
      assert log =~ "Could not stat asset at #{path}, did you forget to build it?"
      assert_received {:stat, %File.Stat{size: 0, mtime: mtime, atime: atime, ctime: ctime}}
      assert mtime >= now and atime >= now and ctime >= now
    end
  end

  describe "include/1" do
    test "wraps the contents in markers and disables source maps", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "app.js")
      File.write!(path, "console.log(1);\n//# sourceMappingURL=app.js.map")

      assert Assets.include(path) ==
               "//__BEGIN__ #{path}\nconsole.log(1);\n// app.js.map\n//__END__ #{path}\n"
    end

    test "logs an error and includes a comment when the file is missing", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "missing.js")

      log =
        capture_log(fn ->
          assert Assets.include(path) =~ "// Could not read asset at #{path}\n"
        end)

      assert log =~ "Could not read asset at #{path}"
    end
  end

  describe "read_cache_manifest/2" do
    test "returns the decoded manifest", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "cache_manifest.json")
      File.write!(path, ~s({"latest": {"app.css": "app-123.css"}, "version": 1}))

      assert Assets.read_cache_manifest(path) == %{"latest" => %{"app.css" => "app-123.css"}, "version" => 1}
      assert Assets.read_cache_manifest(path, "latest") == %{"app.css" => "app-123.css"}
      assert Assets.read_cache_manifest(path, "missing") == %{}
    end

    test "returns an empty map when the manifest is missing", %{tmp_dir: tmp_dir} do
      assert Assets.read_cache_manifest(Path.join(tmp_dir, "missing.json")) == %{}
      assert Assets.read_cache_manifest(Path.join(tmp_dir, "missing.json"), "latest") == %{}
    end
  end
end
