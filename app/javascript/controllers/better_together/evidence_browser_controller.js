import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["citationSelect", "locatorInput", "quotedTextInput"]

  chooseCitation(event) {
    event.preventDefault()

    const button = event.currentTarget
    if (this.hasCitationSelectTarget) {
      this.citationSelectTarget.value = button.dataset.citationId
      this.citationSelectTarget.dispatchEvent(new Event("change", { bubbles: true }))
    }

    if (this.hasLocatorInputTarget && !this.locatorInputTarget.value.trim() && button.dataset.locator) {
      this.locatorInputTarget.value = button.dataset.locator
    }

    if (this.hasQuotedTextInputTarget && !this.quotedTextInputTarget.value.trim() && button.dataset.excerpt) {
      this.quotedTextInputTarget.value = button.dataset.excerpt
    }
  }
}
