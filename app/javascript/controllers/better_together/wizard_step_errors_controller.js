// Moves keyboard/screen-reader focus to the error summary when a wizard step
// re-renders with validation errors, so the failure is announced immediately
// instead of silently leaving focus wherever the form submit button was.
// See docs/plans/richer_platform_setup_wizard_implementation_plan.md —
// "Accessibility Design" (a gap in the existing host_setup wizard this
// controller deliberately does not repeat).

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.focus()
  }
}
