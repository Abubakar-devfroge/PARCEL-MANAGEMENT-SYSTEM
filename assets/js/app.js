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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
import "@tailwindplus/elements"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/goods"
import topbar from "../vendor/topbar"



const InfiniteParcels = {
  mounted() {
    this.loading = false

    this.observer = new IntersectionObserver(entries => {
      const shouldLoad = entries.some(entry => entry.isIntersecting)

      if (shouldLoad) {
        this.maybeLoadMore()
      }
    }, {
      root: null,
      rootMargin: "0px 0px 280px 0px",
      threshold: 0.01,
    })

    this.observer.observe(this.el)
  },

  updated() {
    const loadingOnServer = this.el.dataset.loading === "true"

    if (!loadingOnServer) {
      this.loading = false
    }

    if (this.el.dataset.hasMore !== "true" && this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  },

  destroyed() {
    if (this.observer) {
      this.observer.disconnect()
      this.observer = null
    }
  },

  maybeLoadMore() {
    const hasMore = this.el.dataset.hasMore === "true"
    const loadingOnServer = this.el.dataset.loading === "true"

    if (!hasMore || loadingOnServer || this.loading) {
      return
    }

    this.loading = true
    this.pushEvent("load-more", {})
  },
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs:  false,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks, InfiniteParcels},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
let topbarStartedAt = 0
const minTopbarVisibleMs = 150

window.addEventListener("phx:page-loading-start", _info => {
  topbarStartedAt = Date.now()
  topbar.show()
})

window.addEventListener("phx:page-loading-stop", _info => {
  const elapsed = Date.now() - topbarStartedAt
  const remaining = Math.max(0, minTopbarVisibleMs - elapsed)
  window.setTimeout(() => topbar.hide(), remaining)
})

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}

