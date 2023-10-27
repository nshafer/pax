// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/admin.js",
    "../lib/pax/admin.ex",
    "../lib/pax/admin/**/*.*ex",
  ],
  theme: {
    extend: {
      colors: {
        brand: "#FD4F00",
        zinc: {
          150: "rgb(236 236 238)"
        },
        sky: {
          //950: "rgb(8 47 73)",
          925: "rgb(10 56 85)",
          //900: "rgb(12 74 110)",
        }
      },
      height: {
        'header': '4rem'
      }
    },
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
