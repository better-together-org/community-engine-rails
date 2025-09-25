// Event DateTime Controller
// Handles dynamic synchronization between start time, end time, and duration fields
// 
// Behavior:
// - When start time changes: Updates end time based on current duration
// - When end time changes: Updates duration based on start/end time difference  
// - When duration changes: Updates end time based on start time + duration
// - Validates minimum duration (5 minutes)
// - Defaults duration to 30 minutes when not set

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startTime", "endTime", "duration"]

  connect() {
    // Set default duration if not already set
    if (!this.durationTarget.value || this.durationTarget.value === "0") {
      this.durationTarget.value = "30"
    }
    
    // Initialize end time if start time is set but end time is not
    if (this.startTimeTarget.value && !this.endTimeTarget.value) {
      this.updateEndTimeFromDuration()
    }
  }

  // Called when start time changes
  updateEndTime() {
    if (!this.startTimeTarget.value) {
      this.endTimeTarget.value = ""
      return
    }

    // Use current duration or default to 30 minutes
    const duration = this.getDurationInMinutes()
    this.calculateEndTime(duration)
  }

  // Called when end time changes  
  updateDuration() {
    if (!this.startTimeTarget.value || !this.endTimeTarget.value) {
      return
    }

    const startTime = new Date(this.startTimeTarget.value)
    const endTime = new Date(this.endTimeTarget.value)
    
    // Validate end time is after start time
    if (endTime <= startTime) {
      this.showTemporaryError("End time must be after start time")
      return
    }

    // Calculate duration in minutes
    const diffInMs = endTime.getTime() - startTime.getTime()
    const diffInMinutes = Math.round(diffInMs / (1000 * 60))
    
    // Enforce minimum duration
    if (diffInMinutes < 5) {
      this.durationTarget.value = "5"
      this.calculateEndTime(5)
    } else {
      this.durationTarget.value = diffInMinutes.toString()
    }
  }

  // Called when duration changes
  updateEndTimeFromDuration() {
    if (!this.startTimeTarget.value) {
      return
    }

    const duration = this.getDurationInMinutes()
    
    // Enforce minimum duration
    if (duration < 5) {
      this.durationTarget.value = "5"
      this.calculateEndTime(5)
    } else {
      this.calculateEndTime(duration)
    }
  }

  // Helper methods
  getDurationInMinutes() {
    const duration = parseInt(this.durationTarget.value) || 30
    return Math.max(duration, 5) // Minimum 5 minutes
  }

  calculateEndTime(durationMinutes) {
    if (!this.startTimeTarget.value) return

    const startTime = new Date(this.startTimeTarget.value)
    const endTime = new Date(startTime.getTime() + (durationMinutes * 60 * 1000))
    
    // Format for datetime-local input (YYYY-MM-DDTHH:MM)
    const year = endTime.getFullYear()
    const month = String(endTime.getMonth() + 1).padStart(2, '0')
    const day = String(endTime.getDate()).padStart(2, '0')
    const hours = String(endTime.getHours()).padStart(2, '0')
    const minutes = String(endTime.getMinutes()).padStart(2, '0')
    
    this.endTimeTarget.value = `${year}-${month}-${day}T${hours}:${minutes}`
  }

  showTemporaryError(message) {
    // Create or update error message
    let errorElement = this.element.querySelector('.datetime-sync-error')
    
    if (!errorElement) {
      errorElement = document.createElement('div')
      errorElement.className = 'alert alert-warning datetime-sync-error mt-2'
      errorElement.setAttribute('role', 'alert')
      this.element.appendChild(errorElement)
    }
    
    errorElement.textContent = message
    
    // Remove error after 3 seconds
    setTimeout(() => {
      if (errorElement && errorElement.parentNode) {
        errorElement.parentNode.removeChild(errorElement)
      }
    }, 3000)
  }
}
