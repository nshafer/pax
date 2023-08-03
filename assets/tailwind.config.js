// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/**/*components.*ex"
  ],
  // Add an ancestor selector to all Tailwind utilities so that they are scoped to children of "#pax" root element
  // Note: this does not apply to Components, such as .container
  important: "#pax",
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
      }
    },
  },
  corePlugins: {
    // Disable preflight as we have a customized version scoped to #pax in css/pax.css
    preflight: false,
  },
  experimental: {
    optimizeUniversalDefaults: true
  },
  plugins: [
    // Configure forms to require form-* classes, instead of applying reset styles to all form elements
    require("@tailwindcss/forms")({
      strategy: 'class'
    }),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({addVariant}) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),
  ]
}
