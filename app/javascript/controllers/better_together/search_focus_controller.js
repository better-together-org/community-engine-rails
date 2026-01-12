import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.boundFocus = this.focusInput.bind(this)
    this.element.addEventListener('shown.bs.collapse', this.boundFocus)
  }

  disconnect() {
    if (this.boundFocus) this.element.removeEventListener('shown.bs.collapse', this.boundFocus)
  }

  focusInput() {
    // Prefer input[name=q] or first text/search input inside the collapse
    const input = this.element.querySelector('input[name="q"], input[type="search"], input[type="text"]')
    if (!input) return
    input.focus({ preventScroll: true })
    // Move caret to end for convenience
    try { input.setSelectionRange(input.value.length, input.value.length) } catch (e) {}
  }
}
