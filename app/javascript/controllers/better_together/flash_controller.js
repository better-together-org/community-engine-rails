import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    if (this.hasMessageTarget) {
      this.dismissAfterDelay(); // Dismiss after a delay when connected
    }
  }

  dismissAfterDelay() {
    setTimeout(() => {
      this.messageTargets.forEach(message => {
        if (!message.classList.contains('alert-danger')) {
          message.remove(); // Remove the alert element from the DOM
        }
      });
    }, 10000); // Dismiss after 10000 milliseconds
  }
}
