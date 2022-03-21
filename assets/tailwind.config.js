// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
  content: ["./js/**/*.js", "../lib/*_web.ex", "../lib/*_web/**/*.*ex"],
  theme: {
    fontFamily: {
      draw: ["Just Another Hand", "cursive"],
      sans: ["ui-sans-serif", "system-ui"],
    },
    extend: {},
  },
  plugins: [require("@tailwindcss/forms")],
};
