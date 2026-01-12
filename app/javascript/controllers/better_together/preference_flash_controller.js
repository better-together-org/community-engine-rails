// app/javascript/controllers/better_together/preference_flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Listen for custom flash events from child preference fields
    this.element.addEventListener('preference:flash', this.handleFlash.bind(this))
  }

  disconnect() {
    this.element.removeEventListener('preference:flash', this.handleFlash.bind(this))
  }

  handleFlash(event) {
    const { type, message } = event.detail
    this.showFlashMessage(type, message)
  }

  showFlashMessage(type, message) {
    // Find the flash messages turbo frame
    const flashFrame = document.getElementById('flash_messages')
    if (!flashFrame) {
      console.warn('Flash messages frame not found')
      return
    }

    // Get the container inside the frame
    const flashContainer = flashFrame.querySelector('#col-flash-message')
    if (!flashContainer) {
      console.warn('Flash messages container not found')
      return
    }

    // Create alert element matching Rails flash message style
    const alert = this.createAlert(type, message)
    
    // Clear existing messages and add new one
    flashContainer.innerHTML = ''
    flashContainer.appendChild(alert)

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      const bsAlert = bootstrap.Alert.getOrCreateInstance(alert)
      bsAlert.close()
    }, 5000)

    // Scroll to top to show message
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  createAlert(type, message) {
    const alertClass = type === 'success' ? 'alert-success' : 'alert-danger'
    
    const alert = document.createElement('div')
    alert.className = `alert ${alertClass} alert-dismissible fade show text-center`
    alert.setAttribute('role', 'alert')
    alert.setAttribute('data-better_together--flash-target', 'message')
    
    alert.innerHTML = `
      ${this.escapeHtml(message)}
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `
    
    return alert
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
