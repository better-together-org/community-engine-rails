import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox"]
  static values = {
    onlyOne: Boolean,
    group: String
  }

  connect() {
    if (this.onlyOneValue) {
      this.enforceSingleSelection()
    }
  }

  toggle(event) {
    if (this.onlyOneValue && event.target.checked) {
      this.uncheckOtherCheckboxesInGroup(event.target)
    }
  }

  enforceSingleSelection() {
    const checkboxesInGroup = this.getCheckboxesInGroup()
    const anyChecked = checkboxesInGroup.some(checkbox => checkbox.checked)

    if (!anyChecked && checkboxesInGroup.length > 0) {
      // Ensure at least one checkbox is checked if none are checked
      checkboxesInGroup[0].checked = true
    }
  }

  uncheckOtherCheckboxesInGroup(currentCheckbox) {
    const checkboxesInGroup = this.getCheckboxesInGroup()

    checkboxesInGroup.forEach(checkbox => {
      if (checkbox !== currentCheckbox) {
        checkbox.checked = false
      }
    })
  }

  getCheckboxesInGroup() {
    const container = this.element.closest('[data-better_together--dynamic-fields-target="container"]')
    const allCheckboxes = container.querySelectorAll('input[type="checkbox"].toggle-switch')

    if (this.hasGroupValue) {
      // Filter checkboxes by group
      return Array.from(allCheckboxes).filter(checkbox => checkbox.dataset.group === this.groupValue)
    }

    // If no group is specified, return all checkboxes
    return Array.from(allCheckboxes)
  }
}
