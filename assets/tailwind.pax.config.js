// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

module.exports = {
  content: [
    "./js/pax.js",
  ],
  corePlugins: {
    // Disable preflight, just in case. It shouldn't be included without the 'base' tailwind layer.
    preflight: false,
  },
  experimental: {
    optimizeUniversalDefaults: true
  },
}
