// app/javascript/controllers/notification_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { markReadUrl: String }

  connect() {
    this.handleTitleClick = this.handleTitleClick.bind(this)
    this.titleLink = this.element.querySelector('h5 a')
    if (this.titleLink) {
      this.titleLink.addEventListener('click', this.handleTitleClick)
    }
  }

  disconnect() {
    if (this.titleLink) {
      this.titleLink.removeEventListener('click', this.handleTitleClick)
    }
  }

  handleTitleClick(event) {
    event.preventDefault()

    // Make an AJAX request to mark the notification as read
    fetch(this.markReadUrlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content'),
        'Accept': 'text/vnd.turbo-stream.html',
      }
    }).then(response => {
      if (response.ok) {
        // Turbo Stream will handle the badge update
        // After marking as read, follow the link
        window.location = event.target.href
      }
    })
  }
}
