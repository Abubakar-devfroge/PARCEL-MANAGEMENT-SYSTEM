// assets/tailwind.config.js
const defaultTheme = require("tailwindcss/defaultTheme")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/goods_web.ex",        
    "../lib/goods_web/**/*.*ex"
  ],
  theme: {
    extend: {
      fontFamily: {
        // Full production font stack (Inter + system fallbacks)
        sans: [
          "Inter",
          "system-ui",
          "-apple-system",
          "BlinkMacSystemFont",
          "Segoe UI",
          "Roboto",
          "Helvetica Neue",
          "Arial",
          "Noto Sans",
          "sans-serif",
          "Apple Color Emoji",
          "Segoe UI Emoji",
          "Segoe UI Symbol",
          "Noto Color Emoji"
        ],

        // KEEPING your mono exactly as required
        mono: ["JetBrains Mono", ...defaultTheme.fontFamily.mono],
      },

      colors: {
        brand: {
          dark: "#0F172A",
          primary: "#2563EB",
        }
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography")
  ]
}