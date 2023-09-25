defmodule Pax.Util.Inflection do
  @moduledoc """
  Utilities for inflecting the plural form of singular nouns. This isn't trying to be perfect, just good enough.

  Inspired by Kaffy Copyright (c) 2020 Abdullah Esmail licensed under a MIT License
  https://github.com/aesmail/kaffy/blob/master/lib/kaffy/inflector.ex

  Also using rules summarized from https://users.monash.edu/~damian/papers/HTML/Plurals.html
  """

  # TODO: actually implement this...

  def pluralize(noun) when is_binary(noun) do
    noun <> "s"
  end
end
