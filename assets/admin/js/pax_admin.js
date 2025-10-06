// Pax Admin JS

// Note: Phoenix dependencies are injected here from their Application directories by the Pax.Admin.Assets module.
//       This is done so that we load whatever versions are currently installed by the application including `:pax`
//       as a dependency, and the version of `:phoenix`, `:phoenix_live_view`, etc. that the application is using may
//       be different than the version that `:pax` has as its own dependencies at the time it was published. This loads
//       them directly as global variables (window.Phoenix, window.LiveView, etc). The result is the same as:
//
// var Phoenix = {...}
// var LiveView = {...}
//
//       The equivalent ECMAScript module `import` statements are:
//
// import "phoenix_html"
// import * as Phoenix from "phoenix"
// import * as LiveView from "phoenix_live_view"


import topbar from "../vendor/topbar"

// Establish Phoenix Socket and LiveView configuration.
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveView.LiveSocket("/live", Phoenix.Socket, { params: { _csrf_token: csrfToken } })

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

