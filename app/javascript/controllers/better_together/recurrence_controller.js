import { Controller } from "@hotwired/stimulus"

const PREVIEW_DEBOUNCE_MS = 300

// Manages recurrence form visibility and preview
export default class extends Controller {
  static targets = [
    "frequencyField",
    "intervalField",
    "intervalUnitLabel",
    "endTypeField",
    "untilDateField",
    "endsOnInput",
    "countField",
    "countInput",
    "weekdaysField",
    "neverEndsWarning",
    "seriesNote",
    "preview"
  ]

  static values = {
    previewUrl: String,
    dayUnitLabel: String,
    weekUnitLabel: String,
    monthUnitLabel: String,
    yearUnitLabel: String
  }

  connect() {
    this.updateVisibility()
    this.updateIntervalUnitLabel()

    // Editing an event that already has a recurrence configured should show
    // the preview immediately, not wait for the user to touch a field first.
    if (this.hasFrequencyFieldTarget && this.frequencyFieldTarget.value) {
      this.updatePreview()
    }
  }

  disconnect() {
    this.clearPreviewDebounce()
  }

  // Update form field visibility based on selections
  updateVisibility() {
    const frequency = this.hasFrequencyFieldTarget ? this.frequencyFieldTarget.value : null
    const endType = this.hasEndTypeFieldTarget ? this.endTypeFieldTarget.value : null

    // Show/hide weekday selector for weekly frequency
    if (this.hasWeekdaysFieldTarget) {
      const isVisible = frequency === 'weekly'
      this.weekdaysFieldTarget.style.display = isVisible ? 'block' : 'none'
      this.weekdaysFieldTarget.setAttribute('aria-hidden', !isVisible)
    }

    // Show/hide end type fields
    if (this.hasUntilDateFieldTarget) {
      const isVisible = endType === 'until'
      this.untilDateFieldTarget.style.display = isVisible ? 'block' : 'none'
      this.untilDateFieldTarget.setAttribute('aria-hidden', !isVisible)
    }

    if (this.hasCountFieldTarget) {
      const isVisible = endType === 'count'
      this.countFieldTarget.style.display = isVisible ? 'block' : 'none'
      this.countFieldTarget.setAttribute('aria-hidden', !isVisible)
    }

    // Warn when the recurrence has no end date at all — "never" is the
    // default selection, so this is easy to leave in place by accident.
    if (this.hasNeverEndsWarningTarget) {
      const isVisible = Boolean(frequency) && endType === 'never'
      this.neverEndsWarningTarget.style.display = isVisible ? 'block' : 'none'
      this.neverEndsWarningTarget.setAttribute('aria-hidden', !isVisible)
    }

    // Remind the user that editing a recurring event's fields changes the
    // whole series — there is no per-occurrence edit in this system.
    if (this.hasSeriesNoteTarget) {
      const isVisible = Boolean(frequency)
      this.seriesNoteTarget.style.display = isVisible ? 'block' : 'none'
      this.seriesNoteTarget.setAttribute('aria-hidden', !isVisible)
    }

    this.updateIntervalUnitLabel()
  }

  // Show which unit the interval number applies to (e.g. "2 [week(s)]")
  // since frequency changes what "every N" actually counts.
  updateIntervalUnitLabel() {
    if (!this.hasIntervalUnitLabelTarget) return

    const labels = {
      daily: this.hasDayUnitLabelValue ? this.dayUnitLabelValue : 'day(s)',
      weekly: this.hasWeekUnitLabelValue ? this.weekUnitLabelValue : 'week(s)',
      monthly: this.hasMonthUnitLabelValue ? this.monthUnitLabelValue : 'month(s)',
      yearly: this.hasYearUnitLabelValue ? this.yearUnitLabelValue : 'year(s)'
    }

    const frequency = this.hasFrequencyFieldTarget ? this.frequencyFieldTarget.value : null
    this.intervalUnitLabelTarget.textContent = labels[frequency] || ''
  }

  // Debounced preview fetch — avoids firing one request per keystroke/click
  // when several fields change in quick succession.
  updatePreview() {
    this.clearPreviewDebounce()
    this.previewDebounceTimer = setTimeout(() => this.fetchPreview(), PREVIEW_DEBOUNCE_MS)
  }

  clearPreviewDebounce() {
    if (this.previewDebounceTimer) {
      clearTimeout(this.previewDebounceTimer)
      this.previewDebounceTimer = null
    }
  }

  fetchPreview() {
    if (!this.hasPreviewTarget || !this.hasPreviewUrlValue) return

    const params = this.buildPreviewParams()
    const url = `${this.previewUrlValue}?${params}`

    this.previewTarget.classList.add('opacity-50')

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
      .finally(() => {
        this.previewTarget.classList.remove('opacity-50')
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

    // Note: untilDateFieldTarget/countFieldTarget are the wrapping <div>s
    // used for show/hide (a <div> has no .value) — read the actual inputs
    // from their own dedicated targets instead.
    if (this.hasEndsOnInputTarget && this.endsOnInputTarget.value) {
      // Server-side param name matches the Recurrence model's own `ends_on`
      // attribute (not `until_date`) so it flows straight into
      // RecurrenceScheduleBuilder without a second name for the same field.
      params.append('ends_on', this.endsOnInputTarget.value)
    }

    if (this.hasCountInputTarget && this.countInputTarget.value) {
      params.append('count', this.countInputTarget.value)
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
