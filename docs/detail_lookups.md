# Notes regarding detail lookup refactor

## Problem statement

- Adapter should not be passed `uri` or `params`... that's a leaking of concerns
- EctoSchema adapter has a configurable `id_field` option, that shouldn't be needed
- Phoenix merges all params into one map, `params`, in handle_params, and with LV there is no other way to separate
  GET from POST from url prams. That leads to ambiguous params, which is a security concern, example:
  http://localhost:4000/books/11-alice-s-adventures-in-wonderland?id=12 resulting in pulling up book with id 12 and
  not the intended Alice's Adventures in Wonderland.
- Plug.Parsers merges params by this priority (Plug.Parsers line 378):
  - query params
  - body params
  - path params
- Would be nice to support multiple IDs, such as composite primary keys, in both Interface and Admin

## Desired behavior

Whereby:
- Map path param -> lookup map:
  - `live "/authors/:id", AuthorLive, :show` -> `%{"id" => "3"}`
  - `live "/books/:id", BookLive, :show` -> `%{"slug" => "11-alice-s-adventures-in-wonderland"}`
  - `live "/books/:slug/edit", BookLive, :edit` -> `%{"slug" => "11-alice-s-adventures-in-wonderland"}`
  - `live "/books/:id/:slug, BookLive, :show` -> `%{id => "3", "slug" => "11-alice-s-adventures-in-wonderland"}`

- Map path glob -> lookup map:
  - `live "/books/edit/*ids", BookLive, :edit` -> `%{"id" => "3", "slug" => "11-alice-s-adventures-in-wonderland"}

Facts:
- The lookup params need to be configurable, so we know which param to lookup. Default `["id"]`
- The query fields of the object needs to be configurable, so we know what fields to lookup by. Default: `[:id]`
- The Pax.Interface should handle parsing the params, and only look for the params that are in the
  `Conn.path_params`, ignoring `Conn.query_params` and `Conn.body_params`, even though they are merged, but this is
  only possible if the dev configures things properly.
- Default to `["id"]` for the param since that's what will be used in the admin, and also the default in the docs for
  how to set up a Pax.Interface module, as in `live "/books/:id", BookLive, :show`.
- Default to `[:id]` for the id field on the object for lookups, since this is the most common most likely. It's the
  default for ecto, postgres docs, json apis for the most part. Obviously something won't have this default.
- Configurable with `lookup_params` config variable. Default: `["id"]`. These are the values to pull out of the params
  for looking up the object.
- Configurable with `id_fields` config variable. Default: `[:id]`. These are the fields of the object to perform the
  lookup on.
- The adapter should be passed a `lookup` map, consisting of keys and values to basically use for the where clause.
- Adapter's `id_fields` callback should just be a way for the adapter to help Pax.Interface figure out a default id
  fields, such as EctoSchema looking up the primary_key(s) of the schema.
- Adapter should not have any configuration for the id field, like it does now.
- Module should be able to define a `lookup` config function callback that takes the `uri` and `params` to return
  a `lookup` map from, so the user has ultimate control.
- The admin has hard coded urls, so we'll use a path glob to match any number of ids, configurable with only the
  `id_fields` config variable for both building paths as well as doing lookups.

## Fixes

- [x] Implement `init_lookup` in Pax.Interface
  - [x] Check if user defined a `lookup` config callback, if so call it and return it.
  - [x] Check if user defined a `lookup_params` array of strings (or callback) and get it's value, default to `["id"]`.
  - [x] Check if user defined a `lookup_glob` string (or callback) and get it's value.
  - [x] If user defined by `lookup_params` and `lookup_glob`, raise error.
  - [x] If user did not define either `lookup_params` or `lookup_glob`, default to `lookup_params` of `["id"]`.
  - [x] Get all of the `param_values` from the `params` using either `lookup_params` or `lookup_glob`.
  - [x] Check if user defined a `id_fields` array of atoms (or callback) and get it's value, default to whatever the
    adapter returns from `id_fields` callback, which EctoSchema will default to `schema.__schema__(:primary_key)`,
    which in most cases will be `[:id]`.
  - [x] Check that the param values and id fields arrays match in length. Raise if they don't.
  - [x] Zip the two lists, `id_fields` and `param_values` into a map and return it.
    `Enum.zip([:id, :slug], ["3", "alice-in-wonderland"]) |> Map.new()`
- [x] Pass the lookup map to the adapter in `get_object` instead of `uri` and `params`.
    - [x] Update EctoSchema adapter to construct a where clause based on the lookup map.
- [x] Remove `id_field` config option from EctoSchema adapter.
- [x] Remove `uri` and `params` from adapter `new_object`. It should just return an empty map (or struct).
- [x] Update the admin to work with these changes.

