// We import the CSS which is extracted to its own file by esbuild.
// Remove this line if you add a your own CSS build pipeline (e.g postcss).

// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html";
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import topbar from "../vendor/topbar";
import { Howl } from "howler";
import LiveReact, { initLiveReact } from "phoenix_live_react";

Hooks = {};

Hooks.LiveReact = LiveReact;

Hooks.Share = {
  mounted() {
    this.el.addEventListener("click", async (e) => {
      // Share must be triggered by "user activation"
      try {
        await navigator.share({
          title: "Bid Tac Toe",
          text: "Play Bid Tac Toe with me!",
          url: e.target.innerHTML,
        });
      } catch (err) {}
    });
  },
};
Hooks.PlaySound = {
  mounted() {
    this.handleEvent("play-sound", ({}) => {
      var sound = new Howl({
        src: [
          "https://interactive-examples.mdn.mozilla.net/media/cc0-audio/t-rex-roar.mp3",
        ],
        volume: 0.5,
      });
      sound.play();
    });
  },
};
Hooks.SetUsername = {
  // Called when a LiveView is mounted, if it includes an element that uses this hook.
  mounted() {
    this.handleEvent("set-username", ({ username }) => {
      console.log("api called");
      // Ajax request to update session.
      fetch(`/api/session?username=${encodeURIComponent(username)}`, {
        method: "post",
      });

      this.pushEventTo(
        ".phx-hook-subscribe-to-session",
        "updated_session_data",
        { username: username }
      );
    });
  },
};

Hooks.Confetti = {
  mounted() {
    confetti({
      origin: { y: 0.0 },
      spread: 150,
      particleCount: 300,
      gravity: 3,
    });
  },
};

let csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");
let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
});

document.addEventListener("DOMContentLoaded", (e) => {
  initLiveReact();
});

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" });
window.addEventListener("phx:page-loading-start", (info) => topbar.show());
window.addEventListener("phx:page-loading-stop", (info) => topbar.hide());

// connect if there are any LiveViews on the page
liveSocket.connect();

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket;
