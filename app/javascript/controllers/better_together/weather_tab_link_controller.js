import { Controller } from "@hotwired/stimulus"

// Opens the settlement Weather tab from a link elsewhere on the page. It clicks the real tab link so the
// tabs controller keeps the active tab, pane and URL hash in step. Without JavaScript the #weather href applies.
export default class extends Controller {
  open(event) {
    const tab = document.getElementById("weather-tab")
    if (!tab) return

    event.preventDefault()
    tab.click()
    tab.scrollIntoView({ behavior: "smooth", block: "start" })
    tab.focus({ preventScroll: true })
  }
}
