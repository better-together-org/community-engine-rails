// app/javascript/better_together/controllers/message_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.contentTarget.addEventListener("keydown", this.handleKeydown.bind(this));
    this.setFocus();
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault(); // Prevent the default Enter behavior
      this.element.requestSubmit(); // Submit the form
    }
  }

  setFocus() {
    this.contentTarget.focus();
  }

  reset() {
    this.setFocus();
  }

  disconnect() {
    this.contentTarget.removeEventListener("keydown", this.handleKeydown.bind(this));
  }
}
