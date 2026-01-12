// app/assets/javascripts/controllers/better_together/lazy_notifications_controller.js
import AppController from "controllers/better_together/app_controller"

export default class extends AppController {
  static targets = [ "dropdown", "content" ]
  static values = { 
    loaded: Boolean,
    url: String
  }

  connect() {
    this.loadedValue = false
    this.debug.log('Lazy notifications controller connected with URL:', this.urlValue)
    
    // Find the dropdown toggle element (the <a> tag with data-bs-toggle="dropdown")
    const dropdownToggle = this.element.querySelector('[data-bs-toggle="dropdown"]')
    
    if (dropdownToggle) {
      this.debug.log('Found dropdown toggle, adding event listener')
      // Listen for Bootstrap dropdown show event on the dropdown toggle
      // Always reload notifications when dropdown is opened
      dropdownToggle.addEventListener('show.bs.dropdown', (event) => {
        this.debug.log('Bootstrap dropdown show event triggered')
        this.loadContent()
      })
    } else {
      this.debug.warn('No dropdown toggle found')
    }
  }

  toggle(event) {
    // This method can be removed or kept for debugging
    this.debug.log('Dropdown toggle clicked')
  }

  async loadContent() {
    this.debug.log('Loading notifications from:', this.urlValue)
    
    try {
      // Show loading state
      this.contentTarget.innerHTML = `
        <div class="text-center p-3">
          <div class="spinner-border spinner-border-sm" role="status">
            <span class="visually-hidden">Loading...</span>
          </div>
          <div class="mt-2">Loading notifications...</div>
        </div>
      `
      
      const response = await fetch(this.urlValue, {
        headers: {
          'Accept': 'text/html'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.contentTarget.innerHTML = html
      } else {
        this.contentTarget.innerHTML = `
          <div class="text-danger text-center p-3">
            Failed to load notifications
          </div>
        `
      }
    } catch (error) {
      this.debug.error('Error loading notifications:', error)
      this.contentTarget.innerHTML = `
        <div class="text-danger text-center p-3">
          Error loading notifications
        </div>
      `
    }
  }
}
