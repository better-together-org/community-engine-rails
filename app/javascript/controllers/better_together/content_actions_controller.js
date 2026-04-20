import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["extensions", "panel", "summary"]

  connect() {
    this.boundCloseOnWindowClick = this.closeOnWindowClick.bind(this)
    window.addEventListener("click", this.boundCloseOnWindowClick, true)
    this.sync()
  }

  disconnect() {
    window.removeEventListener("click", this.boundCloseOnWindowClick, true)
  }

  sync() {
    if (this.hasSummaryTarget) {
      this.summaryTarget.setAttribute("aria-expanded", this.openValue)
    }

    this.dispatch(this.element.open ? "opened" : "closed", {
      prefix: "better-together:content-actions",
      detail: {
        id: this.element.id,
        open: this.element.open
      }
    })
  }

  handleKeydown(event) {
    if (event.key !== "Escape" || !this.element.open) return

    event.preventDefault()
    this.close({ focusSummary: true })
  }

  closeOnWindowClick(event) {
    if (!this.element.open || this.element.contains(event.target)) return

    this.close()
  }

  close({ focusSummary = false } = {}) {
    if (!this.element.open) return

    this.element.open = false
    this.sync()

    if (focusSummary && this.hasSummaryTarget) {
      this.summaryTarget.focus()
    }
  }

  get openValue() {
    return this.element.open ? "true" : "false"
  }
}
