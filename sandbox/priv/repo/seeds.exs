# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Sandbox.Repo.insert!(%Sandbox.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.
alias Sandbox.Repo

# Seed the random number generator so it's always the same
# :rand.seed(:exsss, {?p, ?a, ?x})
Logger.configure(level: :info)

num_labels = 10
num_artists = 100
num_albums = 500

defmodule Seed do
  @words ~w(
    black blue brown green orange pink purple red white yellow aqua azure beige bisque coral crimson cyan fuchsia
    one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen
    intelligent wise smart clever bright brilliant genius brainy gifted talented knowledgeable insightful perceptive
    phony fake false bogus counterfeit forged fraudulent imitation mock sham spurious affected artificial assumed
    wiggly wobbly jiggly jello gelatinous quivering quaking shaking shivering shuddering shivery shivery trembly
    oatmeal porridge gruel mush paste pablum pap cream of wheat cream of rice cream of barley cream of oats
    squeeze press pinch compress nip grasp clutch grip clasp cling clench clinch embrace hug cuddle enfold
    broken busted smashed shattered fragmented crushed demolished destroyed ruined annihilated devastated ravaged
    happy glad joyful cheerful cheery merry delighted jovial jolly gleeful overjoyed ecstatic elated euphoric
    selfless unselfish altruistic generous magnanimous philanthropic humanitarian charitable benevolent public-spirited
    strong powerful mighty stalwart stout sturdy robust tough hardy rugged brawny burly hefty husky sinewy
    breezy blustery blowy gusty stormy tempestuous squally windy drafty draughty airy blustering boisterous fresh
    texture grain fabric weave web fiber fibre thread yarn strand filament string cord rope wire twine
    competent capable able proficient skilled adept adroit dexterous deft handy masterly virtuoso consummate polished
    compete contend vie challenge rival oppose contest emulate strive struggle battle clash joust grapple wrestle
    protest object complain remonstrate expostulate demur oppose dissent kick inveigh rail fulminate gripe grouse beef
    finicky fussy picky choosy fastidious persnickety dainty squeamish squeamish delicate refined subtle dainty
    gaudy flashy garish loud showy tawdry vulgar brassy flamboyant glitzy jazzy kitschy ostentatious pretentious
    giddy dizzy vertiginous woozy light-headed lightheaded faint-headed weak-kneed weak in the knees wobbly
    glib slick smooth pat facile ready fluent easy effortless offhand unhesitating unthinking automatic instinctive
    gregarious sociable social outgoing friendly affable amiable genial congenial cordial warm convivial companionable
    classy elegant stylish chic fashionable smart sophisticated tasteful modish dashing debonair suave urbane polished
    swanky posh ritzy plush plushy deluxe luxurious opulent sumptuous palatial lavish grand rich fancy
  )

  @label_suffixes ~w(records recordings music tunes songs melodies harmonies rhythms beats grooves sounds noise)

  def slugify(str) do
    str
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]/, "-")
    |> String.replace(~r/^-/, "")
    |> String.replace(~r/-$/, "")
  end

  def titleize(l) when is_list(l) do
    l
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def titleize(s) when is_binary(s) do
    s
    |> String.split()
    |> titleize()
  end

  def random_label_name() do
    words = Enum.take_random(@words, :rand.uniform(2))
    suffix = Enum.take_random(@label_suffixes, 1)
    (words ++ suffix) |> titleize()
  end

  def random_artist_name() do
    Enum.take_random(@words, :rand.uniform(3))
    |> titleize()
  end

  def random_album_name() do
    Enum.take_random(@words, :rand.uniform(3))
    |> titleize()
  end

  def random_rating() do
    :rand.uniform() * 5.0
  end

  def random_album_length() do
    30 + :rand.uniform(90)
  end

  def random_year(), do: Enum.random(1900..2020)
  def random_month(), do: Enum.random(1..12)
  def random_day(), do: Enum.random(1..28)
  def random_hour(), do: Enum.random(0..23)
  def random_minute(), do: Enum.random(0..59)
  def random_second(), do: Enum.random(0..59)
  def random_date(), do: %Date{year: random_year(), month: random_month(), day: random_day()}

  def random_time(),
    do: %Time{hour: random_hour(), minute: random_minute(), second: random_second()}

  def random_naive_datetime(), do: NaiveDateTime.new!(random_date(), random_time())
end

# Labels
alias Sandbox.Library.Label

IO.puts("Generating #{num_labels} labels...")

Enum.map(1..num_labels, fn _ ->
  name = Seed.random_label_name()

  %Label{
    name: name,
    slug: Seed.slugify(name),
    rating: Enum.random([nil, Seed.random_rating()]),
    founded: Seed.random_year(),
    accepting_submissions: Enum.random([true, false])
  }
end)
|> Enum.map(fn l -> Repo.insert!(l, on_conflict: :nothing) end)

labels = Repo.all(Label)

# Artists
alias Sandbox.Library.Artist

IO.puts("Generating #{num_artists} artists...")

Enum.map(1..num_artists, fn _ ->
  name = Seed.random_artist_name()

  %Artist{
    name: name,
    slug: Seed.slugify(name),
    rating: Enum.random([nil, Seed.random_rating()]),
    started: Seed.random_naive_datetime(),
    ended: Enum.random([nil, Seed.random_naive_datetime()]),
    current_label_id: Enum.random([nil, Enum.random(labels).id])
  }
end)
|> Enum.map(fn a -> Repo.insert!(a, on_conflict: :nothing) end)

artists = Repo.all(Artist)

# Albums
alias Sandbox.Library.Album

IO.puts("Generating #{num_albums} albums...")

Enum.map(1..num_albums, fn _ ->
  artist = Enum.random(artists)

  %Album{
    name: Seed.random_album_name(),
    rating: Enum.random([nil, Seed.random_rating()]),
    length_sec: Seed.random_album_length(),
    artist_id: artist.id,
    label_id: Enum.random([nil, artist.current_label_id, Enum.random(labels).id])
  }
end)
|> Enum.map(fn a -> Repo.insert(a, on_conflict: :nothing) end)
