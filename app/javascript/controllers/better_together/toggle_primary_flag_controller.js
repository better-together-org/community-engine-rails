import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]

  connect() {
    // Find all checkboxes within the same container
    const container = this.element.closest('[data-dynamic-fields-target="container"]')
    const allCheckboxes = container.querySelectorAll('input[type="checkbox"].primary-switch')

    // Exclude the current checkbox
    const otherCheckboxes = Array.from(allCheckboxes).filter(checkbox => checkbox !== this.checkboxTarget)
    const anyOtherChecked = otherCheckboxes.some(checkbox => checkbox.checked)

    if (anyOtherChecked) {
      // Another checkbox is checked; uncheck this one
      this.checkboxTarget.checked = false
    } else {
      // No other checkboxes checked; ensure this one is checked
      this.checkboxTarget.checked = true
    }
  }

  toggle(event) {
    if (event.target.checked) {
      // Uncheck other checkboxes
      const container = this.element.closest('[data-dynamic-fields-target="container"]')
      const allCheckboxes = container.querySelectorAll('input[type="checkbox"].primary-switch')

      allCheckboxes.forEach((checkbox) => {
        if (checkbox !== event.target) {
          checkbox.checked = false
        }
      })
    }
  }
}
