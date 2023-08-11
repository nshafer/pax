# Misc notes

## Static files

Two methods of including statics:

1. Integrate them into your build system.
    - `@import '../../deps/pax/priv/static/pax.css'
    - Create a new pax_admin.css that does `@import '../../deps/pax/priv/static/admin.css'
    - Pros: will be integrated in user's static system:
        - Works with other methods of serving statics: nginx, s3, etc
        - Is cache busted because the files are included in cache_manifest.json
    - Cons:
        - Extra setup steps.

2. Serve them directly from the :pax application
    - Modify endpoint.ex: `plug Plug.Static, at: "/pax", from: :pax, gzip: false`
    - Pros:
        - Less setup steps
    - Cons:
        - files are not cache-busted, and updates to :pax will require force reloads.
