import { Controller } from "@hotwired/stimulus"

// Manages recurrence form visibility and preview
export default class extends Controller {
  static targets = [
    "frequencyField",
    "intervalField",
    "endTypeField",
    "untilDateField",
    "countField",
    "weekdaysField",
    "preview"
  ]

  connect() {
    this.updateVisibility()
  }

  // Update form field visibility based on selections
  updateVisibility() {
    const frequency = this.hasFrequencyFieldTarget ? this.frequencyFieldTarget.value : null
    const endType = this.hasEndTypeFieldTarget ? this.endTypeFieldTarget.value : null

    // Show/hide weekday selector for weekly frequency
    if (this.hasWeekdaysFieldTarget) {
      this.weekdaysFieldTarget.style.display = frequency === 'weekly' ? 'block' : 'none'
    }

    // Show/hide end type fields
    if (this.hasUntilDateFieldTarget) {
      this.untilDateFieldTarget.style.display = endType === 'until' ? 'block' : 'none'
    }

    if (this.hasCountFieldTarget) {
      this.countFieldTarget.style.display = endType === 'count' ? 'block' : 'none'
    }
  }

  // Update preview of upcoming occurrences
  updatePreview() {
    if (!this.hasPreviewTarget) return

    const params = this.buildPreviewParams()
    const url = `/events/recurrence_preview?${params}`

    fetch(url, {
      headers: {
        'Accept': 'text/html',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok')
        }
        return response.text()
      })
      .then(html => {
        this.previewTarget.innerHTML = html
      })
      .catch(error => {
        console.error('Error fetching recurrence preview:', error)
        this.previewTarget.innerHTML = '<p class="text-danger">Unable to load preview</p>'
      })
  }

  // Build URL parameters for preview request
  buildPreviewParams() {
    const params = new URLSearchParams()

    if (this.hasFrequencyFieldTarget) {
      params.append('frequency', this.frequencyFieldTarget.value)
    }

    if (this.hasIntervalFieldTarget) {
      params.append('interval', this.intervalFieldTarget.value)
    }

    if (this.hasEndTypeFieldTarget) {
      params.append('end_type', this.endTypeFieldTarget.value)
    }

    if (this.hasUntilDateFieldTarget && this.untilDateFieldTarget.value) {
      params.append('until_date', this.untilDateFieldTarget.value)
    }

    if (this.hasCountFieldTarget && this.countFieldTarget.value) {
      params.append('count', this.countFieldTarget.value)
    }

    // Add selected weekdays for weekly recurrence
    if (this.hasWeekdaysFieldTarget) {
      const checkedBoxes = this.weekdaysFieldTarget.querySelectorAll('input[type="checkbox"]:checked')
      checkedBoxes.forEach(checkbox => {
        params.append('weekdays[]', checkbox.value)
      })
    }

    return params
  }

  // Handle frequency change
  frequencyChanged() {
    this.updateVisibility()
    this.updatePreview()
  }

  // Handle end type change
  endTypeChanged() {
    this.updateVisibility()
    this.updatePreview()
  }

  // Handle any field change that should update preview
  fieldChanged() {
    this.updatePreview()
  }
}
