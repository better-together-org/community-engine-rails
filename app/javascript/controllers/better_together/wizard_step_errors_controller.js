// Moves keyboard/screen-reader focus to the error summary when a wizard step
// re-renders with validation errors, so the failure is announced immediately
// instead of silently leaving focus on the submit button.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
  }
}
