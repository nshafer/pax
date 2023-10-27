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

        // Add more color values to the default zinc palette
        zinc: {
          25: "rgb(252 252 252)",
          //50: rgb(250, 250, 250)
          75: "rgb(248 248 249)",
          //100: rgb(244, 244, 245)
          150: "rgb(236 236 238)",
          //200: rgb(228, 228, 231)
          250: "rgb(220 220 224)",
          //300: rgb(212, 212, 216)
          //...
          //700: rgb(63, 63, 70)
          750: "rgb(55 55 62)",
          //800: rgb(39, 39, 42)
          850: "rgb(31 31 34)",
          //900: rgb(24, 24, 27)
          925: "rgb(20 20 23)",
          //950: rgb(9, 9, 11)
          975: "rgb(5 5 6)",
        },

        // Add more color values to the default sky palette
        sky: {
          25: "rgb(250 253 255)",
          //50: rgb(240, 249, 255)
          75: "rgb(234 245 254)",
          //100: rgb(224, 242, 254)
          150: "rgb(214 238 253)",
          //200: rgb(186, 230, 253)
          250: "rgb(158 222 252)",
          //300: rgb(125, 211, 252)

          //700: rgb(3, 105, 161)
          750: "rgb(4 93 142)",
          //800: rgb(7, 89, 133)
          850: "rgb(8 80 121)",
          //900: rgb(12, 74, 110)
          925: "rgb(10 56 85)",
          //950: rgb(8, 47, 73)
          975: "rgb(6 37 57)",
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
