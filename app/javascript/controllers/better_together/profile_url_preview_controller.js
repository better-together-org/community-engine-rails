import { Controller } from "@hotwired/stimulus"
import { createDebug } from "better_together/debugger"

export default class extends Controller {
  static values = {
    template: String,
    placeholder: String
  }
  
  connect() {
    this.debug = createDebug('ProfileUrlPreview', this.application)
    this.debug.log('Controller connected')
  }
  
  updatePreview(event) {
    const preview = document.querySelector('#profile-url-preview')
    
    if (preview) {
      const sanitized = this.sanitize(event.target.value)
      
      if (sanitized) {
        const newUrl = this.templateValue.replace(this.placeholderValue, `<strong>${sanitized}</strong>`)
        preview.innerHTML = newUrl
      } else {
        preview.textContent = this.templateValue
      }
    }
  }
  
  sanitize(value) {
    return value.trim().toLowerCase()
      .replace(/[^a-z0-9\s-]/g, '')
      .replace(/\s+/g, '-')
      .replace(/-+/g, '-')
      .replace(/^-|-$/g, '')
  }
}
