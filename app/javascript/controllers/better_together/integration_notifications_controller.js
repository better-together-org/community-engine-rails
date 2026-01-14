import { Controller } from "@hotwired/stimulus"

// Marks integration notifications as read when integrations tab is shown
export default class extends Controller {
  static targets = ["tab"]
  
  connect() {
    // Check if we're already on the integrations tab (e.g., from a direct link)
    const hash = window.location.hash
    if (hash === '#integrations') {
      this.markAsRead()
    }
  }
  
  // Called when the integrations tab is shown
  showTab(event) {
    if (event.target.getAttribute('aria-controls') === 'integrations') {
      this.markAsRead()
    }
  }
  
  async markAsRead() {
    try {
      const locale = document.documentElement.lang || 'en'
      const response = await fetch(`/${locale}/settings/mark_integration_notifications_read`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.marked_read > 0) {
          this.updateNotificationCount(data.marked_read)
        }
      }
    } catch (error) {
      console.error('Failed to mark integration notifications as read:', error)
    }
  }
  
  updateNotificationCount(markedCount) {
    // Find the notification counter badge by its ID
    const badge = document.querySelector('#person_notification_count')
    if (badge) {
      const currentCount = parseInt(badge.textContent) || 0
      const newCount = Math.max(0, currentCount - markedCount)
      
      if (newCount === 0) {
        // Remove the badge entirely when count reaches zero
        badge.remove()
      } else {
        badge.textContent = newCount
      }
    }
  }
  
  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
