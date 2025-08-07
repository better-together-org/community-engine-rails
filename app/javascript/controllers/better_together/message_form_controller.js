// app/javascript/better_together/controllers/message_form_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["content"]

  connect() {
    this.contentTarget.addEventListener("keydown", this.handleKeydown.bind(this));
    this.setFocus();
  }

  handleKeydown(event) {
    // On desktop: Enter submits, Shift+Enter adds newline
    // On mobile: Enter always adds newline (do not submit)
    const isMobile = /Mobi|Android/i.test(navigator.userAgent);

    if (!isMobile && event.key === "Enter" && !event.shiftKey) {
      event.preventDefault(); // Prevent the default Enter behavior
      this.element.requestSubmit(); // Submit the form
    }
    // On mobile, let Enter insert a newline as usual
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
