import { Controller } from "@hotwired/stimulus"

// Opens a tab on the same page from a link elsewhere on it (data-better-together--tab-link-tab-value is the
// tab's element id). It clicks the real tab so the tabs controller keeps the active tab, pane and URL hash in
// step. Without JavaScript the link's own href applies.
export default class extends Controller {
  static values = { tab: String }

  open(event) {
    const tab = document.getElementById(this.tabValue)
    if (!tab) return

    event.preventDefault()
    tab.click()
    tab.scrollIntoView({ behavior: "smooth", block: "start" })
    tab.focus({ preventScroll: true })
  }
}
