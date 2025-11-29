import { Controller } from "@hotwired/stimulus"

// Auto-submit forms with a debounce delay
// 
// Usage:
//   <form data-controller="auto-submit" data-auto-submit-delay-value="500">
//     <input type="text" name="search" data-action="input->auto-submit#scheduleSubmit">
//   </form>
export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  connect() {
    this.timeout = null
    
    // Auto-attach to all input fields in the form
    this.element.querySelectorAll('input[type="text"], input[type="search"], select, textarea').forEach(input => {
      input.addEventListener('input', this.scheduleSubmit.bind(this))
      input.addEventListener('change', this.scheduleSubmit.bind(this))
    })
  }

  disconnect() {
    this.clearTimeout()
  }

  scheduleSubmit() {
    this.clearTimeout()
    
    this.timeout = setTimeout(() => {
      this.submit()
    }, this.delayValue)
  }

  submit() {
    this.clearTimeout()
    
    // Submit the form
    this.element.requestSubmit()
  }

  clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }
}