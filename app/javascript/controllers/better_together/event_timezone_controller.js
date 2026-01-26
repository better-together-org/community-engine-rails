import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="better-together--event-timezone"
export default class extends Controller {
  static targets = ["timezoneSelect", "currentTime"]

  connect() {
    this.updateCurrentTime()
    // Update current time every minute
    this.intervalId = setInterval(() => {
      this.updateCurrentTime()
    }, 60000) // 60 seconds
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  updateCurrentTime() {
    if (!this.hasCurrentTimeTarget || !this.hasTimezoneSelectTarget) {
      return
    }

    const timezone = this.timezoneSelectTarget.value
    
    if (!timezone) {
      this.currentTimeTarget.textContent = ""
      return
    }

    // Format current time in selected timezone using native JavaScript
    try {
      const now = new Date()
      const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone: timezone,
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true,
        timeZoneName: 'short'
      })
      
      this.currentTimeTarget.textContent = `Current time: ${formatter.format(now)}`
    } catch (error) {
      console.error('Error formatting time for timezone:', timezone, error)
      this.currentTimeTarget.textContent = ""
    }
  }

  timezoneChanged() {
    this.updateCurrentTime()
  }
}
