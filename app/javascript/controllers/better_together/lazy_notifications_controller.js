// app/assets/javascripts/controllers/better_together/lazy_notifications_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dropdown", "content" ]
  static values = { 
    loaded: Boolean,
    url: String
  }

  connect() {
    this.loadedValue = false
    console.log('Lazy notifications controller connected with URL:', this.urlValue)
    
    // Find the dropdown toggle element (the <a> tag with data-bs-toggle="dropdown")
    const dropdownToggle = this.element.querySelector('[data-bs-toggle="dropdown"]')
    
    if (dropdownToggle) {
      console.log('Found dropdown toggle, adding event listener')
      // Listen for Bootstrap dropdown show event on the dropdown toggle
      dropdownToggle.addEventListener('show.bs.dropdown', (event) => {
        console.log('Bootstrap dropdown show event triggered')
        if (!this.loadedValue) {
          this.loadContent()
        }
      })
    } else {
      console.log('No dropdown toggle found')
    }
  }

  toggle(event) {
    // This method can be removed or kept for debugging
    console.log('Dropdown toggle clicked')
  }

  async loadContent() {
    if (this.loadedValue) return
    
    console.log('Loading notifications from:', this.urlValue)
    
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
        this.loadedValue = true
      } else {
        this.contentTarget.innerHTML = `
          <div class="text-danger text-center p-3">
            Failed to load notifications
          </div>
        `
      }
    } catch (error) {
      console.error('Error loading notifications:', error)
      this.contentTarget.innerHTML = `
        <div class="text-danger text-center p-3">
          Error loading notifications
        </div>
      `
    }
  }
}
