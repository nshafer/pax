// Pax Hooks
// This works by injecting hooks into the global LiveSocket instance that is set up default for new Phoenix projects.
// 
// TODO: Make this so that it can be included from the deps/ dir by the developer and injected into their
//       LiveSocket instance in a more explicit manner. That is, if we end up needing hooks...

document.addEventListener("DOMContentLoaded", () => {
    console.log("pax.js loaded");

    if (window.liveSocket) {
        console.log("Installing hooks");

        // Example hook to make sure it works
        window.liveSocket.hooks.PaxHook = {
            mounted() {
                console.log("PaxHook mounted");
            }
        }
    } else {
        console.error("Pax was unable to find a LiveSocket instance");
    }
});
