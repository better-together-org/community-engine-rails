import { Controller } from "@hotwired/stimulus"

// Toggles a password/text input field's type to reveal or hide secrets.
// Used for webhook signing secrets and OAuth client secrets.
//
// Targets:
//   field - the <input> whose type toggles between "password" and "text"
//   icon  - the <i> element whose icon class toggles between fa-eye and fa-eye-slash
export default class extends Controller {
  static targets = ["field", "icon"]

  toggle(event) {
    event.preventDefault()

    const field = this.fieldTarget
    const icon = this.iconTarget

    if (field.type === "password") {
      field.type = "text"
      icon.classList.remove("fa-eye")
      icon.classList.add("fa-eye-slash")
    } else {
      field.type = "password"
      icon.classList.remove("fa-eye-slash")
      icon.classList.add("fa-eye")
    }
  }
}
