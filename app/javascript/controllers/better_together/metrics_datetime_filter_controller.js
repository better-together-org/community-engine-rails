// app/javascript/controllers/better_together/metrics_datetime_filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["startDate", "endDate", "applyButton"]
  static values = {
    chartType: String,
    dataUrl: String,
    minDate: String
  }
  static outlets = ["better-together--metrics-charts"]

  connect() {
    this.setMinMaxDates()
    this.setDefaultDates()
    // Automatically load initial data with default date range
    this.loadInitialData()
  }

  // Set reasonable min/max constraints on date inputs
  setMinMaxDates() {
    // Use provided min_date from server, or default to 1 year ago
    const minDateTime = this.hasMinDateValue 
      ? new Date(this.minDateValue)
      : (() => {
          const oneYearAgo = new Date()
          oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1)
          oneYearAgo.setHours(0, 0, 0, 0)
          return oneYearAgo
        })()
    
    const now = new Date()
    now.setHours(23, 59, 59, 999)
    
    const minDate = this.formatDateForInput(minDateTime)
    const maxDate = this.formatDateForInput(now)
    
    this.startDateTarget.setAttribute('min', minDate)
    this.startDateTarget.setAttribute('max', maxDate)
    this.endDateTarget.setAttribute('min', minDate)
    this.endDateTarget.setAttribute('max', maxDate)
  }

  // Set default date range to last 30 days
  setDefaultDates() {
    // Get the minimum allowed date
    const minDateTime = this.hasMinDateValue 
      ? new Date(this.minDateValue)
      : (() => {
          const oneYearAgo = new Date()
          oneYearAgo.setFullYear(oneYearAgo.getFullYear() - 1)
          oneYearAgo.setHours(0, 0, 0, 0)
          return oneYearAgo
        })()
    
    const thirtyDaysAgo = new Date()
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30)
    thirtyDaysAgo.setHours(0, 0, 0, 0) // Start of day
    
    // Ensure start date is not before the minimum allowed date
    const startDate = thirtyDaysAgo < minDateTime ? minDateTime : thirtyDaysAgo
    this.startDateTarget.value = this.formatDateForInput(startDate)

    const now = new Date()
    now.setHours(23, 59, 59, 999) // End of day
    this.endDateTarget.value = this.formatDateForInput(now)
  }

  // Format date for datetime-local input (YYYY-MM-DDThh:mm)
  formatDateForInput(date) {
    const year = date.getFullYear()
    const month = String(date.getMonth() + 1).padStart(2, '0')
    const day = String(date.getDate()).padStart(2, '0')
    const hours = String(date.getHours()).padStart(2, '0')
    const minutes = String(date.getMinutes()).padStart(2, '0')
    return `${year}-${month}-${day}T${hours}:${minutes}`
  }

  // Load initial data on connect
  async loadInitialData() {
    // Small delay to ensure chart controller is connected
    setTimeout(() => {
      this.fetchData()
    }, 100)
  }

  // Apply filter and fetch new data
  async applyFilter(event) {
    event.preventDefault()
    await this.fetchData()
  }

  // Fetch data with current date range
  async fetchData() {
    const startDate = this.startDateTarget.value
    const endDate = this.endDateTarget.value

    if (!this.validateDates(startDate, endDate)) {
      return
    }

    this.setLoadingState(true)

    try {
      const params = new URLSearchParams({
        start_date: new Date(startDate).toISOString(),
        end_date: new Date(endDate).toISOString()
      })

      const response = await fetch(`${this.dataUrlValue}?${params}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        }
      })

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }

      const data = await response.json()
      
      // Dispatch custom event with chart data for the metrics charts controller to handle
      this.dispatch('dataLoaded', { 
        detail: { 
          chartType: this.chartTypeValue, 
          data: data 
        } 
      })

    } catch (error) {
      console.error('Error fetching chart data:', error)
      this.showError(error.message)
    } finally {
      this.setLoadingState(false)
    }
  }

  // Validate date range
  validateDates(startDate, endDate) {
    if (!startDate || !endDate) {
      this.showError('Please select both start and end dates')
      return false
    }

    const start = new Date(startDate)
    const end = new Date(endDate)

    if (start > end) {
      this.showError('Start date must be before end date')
      return false
    }

    // Check for max 1 year range
    const oneYearInMs = 365 * 24 * 60 * 60 * 1000
    if (end - start > oneYearInMs) {
      this.showError('Date range cannot exceed 1 year')
      return false
    }

    return true
  }

  // Reset to default date range (last 30 days)
  async reset(event) {
    event.preventDefault()
    this.setDefaultDates()
    await this.fetchData()
  }

  // Set loading state on button
  setLoadingState(loading) {
    if (this.hasApplyButtonTarget) {
      this.applyButtonTarget.disabled = loading
      const buttonText = this.applyButtonTarget.querySelector('.button-text')
      const spinner = this.applyButtonTarget.querySelector('.spinner-border')
      
      if (loading) {
        if (buttonText) buttonText.classList.add('d-none')
        if (spinner) spinner.classList.remove('d-none')
      } else {
        if (buttonText) buttonText.classList.remove('d-none')
        if (spinner) spinner.classList.add('d-none')
      }
    }
  }

  // Show error message
  showError(message) {
    // Create or update error alert
    let errorAlert = this.element.querySelector('.filter-error-alert')
    
    if (!errorAlert) {
      errorAlert = document.createElement('div')
      errorAlert.className = 'alert alert-danger alert-dismissible fade show filter-error-alert mt-2'
      errorAlert.setAttribute('role', 'alert')
      this.element.appendChild(errorAlert)
    }

    errorAlert.innerHTML = `
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `

    // Auto-dismiss after 5 seconds
    setTimeout(() => {
      const alert = bootstrap.Alert.getOrCreateInstance(errorAlert)
      alert.close()
    }, 5000)
  }

  // Get CSRF token for requests
  getCSRFToken() {
    const tokenElement = document.querySelector("meta[name='csrf-token']")
    return tokenElement ? tokenElement.getAttribute("content") : ""
  }
}
