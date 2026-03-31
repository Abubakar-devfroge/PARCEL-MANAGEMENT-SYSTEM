// assets/tailwind.config.js
const defaultTheme = require("tailwindcss/defaultTheme")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/your_app_web.ex",        // Change 'your_app' to your actual app name
    "../lib/your_app_web/**/*.*ex"
  ],
  theme: {
    extend: {
      fontFamily: {
        // This makes 'Inter' the default font for your whole app
        sans: ["Inter", ...defaultTheme.fontFamily.sans],
        // This is perfect for Tracking IDs and Plate Numbers
        mono: ["JetBrains Mono", ...defaultTheme.fontFamily.mono],
      },
      colors: {
        brand: {
          dark: '#0F172A',
          primary: '#2563EB',
        }
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography")
  ]
}