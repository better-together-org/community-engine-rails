import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]

  connect() {
    if (this.hasMessageTarget) {
      this.dismissAfterDelay(); // Dismiss after a delay when connected
    }
    
    // Ensure positioning is updated when flash messages appear
    this.updatePosition()
  }

  dismissAfterDelay() {
    setTimeout(() => {
      this.messageTargets.forEach(message => {
        if (!message.classList.contains('alert-danger')) {
          message.remove(); // Remove the alert element from the DOM
        }
      });
    }, 7500); // Dismiss after 10000 milliseconds
  }
  
  updatePosition() {
    // Force a reflow to ensure --nav-height is updated
    // This is called when flash messages connect to ensure proper positioning
    requestAnimationFrame(() => {
      const nav = document.getElementById('main-nav')
      if (nav) {
        const height = nav.offsetHeight
        document.documentElement.style.setProperty('--nav-height', `${height}px`)
      }
    })
  }
}
