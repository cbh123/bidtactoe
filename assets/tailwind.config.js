// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration
module.exports = {
  content: ["./js/**/*.js", "../lib/*_web.ex", "../lib/*_web/**/*.*ex"],
  theme: {
    fontFamily: {
      draw: ["Just Another Hand", "cursive"],
      sans: ["ui-sans-serif", "system-ui"],
    },
    extend: {
      animation: {
        fade: "fadeOut 3s ease",
        alert: "quickFade 5s ease",
      },
      keyframes: (theme) => ({
        fadeOut: {
          "0%": {
            opacity: 1,
          },
          "75%": {
            transform: "translate(10px, 50px)",
          },
          "100%": {
            opacity: 0,
          },
        },
        quickFade: {
          "0%": {
            opacity: 1,
          },

          "100%": {
            opacity: 0,
          },
        },
      }),
    },
  },
  plugins: [require("@tailwindcss/forms")],
};
