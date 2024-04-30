import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    setTimeout(() => {
      this.dismiss()
    }, 3000); // Dismiss after 3000 milliseconds
  }

  dismiss() {
    this.element.remove(); // Remove the alert element from the DOM
  }
}
