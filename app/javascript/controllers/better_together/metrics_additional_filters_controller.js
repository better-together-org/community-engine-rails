// app/javascript/controllers/better_together/metrics_additional_filters_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["locale", "pageableType", "hourOfDay", "dayOfWeek", "applyButton"]
  static values = {
    chartType: String,
    dataUrl: String
  }

  connect() {
    // Listen for datetime filter updates to coordinate with them
    document.addEventListener('better-together--metrics-datetime-filter:dataLoaded', this.handleDataUpdate.bind(this))
  }

  disconnect() {
    document.removeEventListener('better-together--metrics-datetime-filter:dataLoaded', this.handleDataUpdate.bind(this))
  }

  // Apply filters and fetch new data
  async applyFilters(event) {
    event.preventDefault()
    await this.fetchData()
  }

  // Fetch data with current filter values
  async fetchData() {
    this.setLoadingState(true)

    try {
      const params = this.buildFilterParams()
      
      console.log('Fetching data from:', `${this.dataUrlValue}?${params}`)
      
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
      
      console.log('Received data:', data)
      console.log('Dispatching dataLoaded event for chart:', this.chartTypeValue)
      
      // Dispatch custom event with chart data for the metrics charts controller to handle
      this.dispatch('dataLoaded', { 
        detail: { 
          chartType: this.chartTypeValue, 
          data: data 
        },
        bubbles: true
      })

    } catch (error) {
      console.error('Error fetching chart data with filters:', error)
      this.showError('Failed to apply filters. Please try again.')
    } finally {
      this.setLoadingState(false)
    }
  }

  // Build URL parameters from filter values
  buildFilterParams() {
    const params = new URLSearchParams()
    
    // Get datetime range from the datetime filter controller if present
    const datetimeFilter = document.querySelector(`[data-better-together--metrics-datetime-filter-chart-type-value="${this.chartTypeValue}"]`)
    if (datetimeFilter) {
      const startDate = datetimeFilter.querySelector('[data-better-together--metrics-datetime-filter-target="startDate"]')
      const endDate = datetimeFilter.querySelector('[data-better-together--metrics-datetime-filter-target="endDate"]')
      
      if (startDate && startDate.value) {
        params.append('start_date', new Date(startDate.value).toISOString())
      }
      if (endDate && endDate.value) {
        params.append('end_date', new Date(endDate.value).toISOString())
      }
    }
    
    // Add additional filter parameters (only if they have non-empty values)
    if (this.hasLocaleTarget && this.localeTarget.value && this.localeTarget.value !== '') {
      params.append('filter_locale', this.localeTarget.value)
    }
    
    if (this.hasPageableTypeTarget && this.pageableTypeTarget.value && this.pageableTypeTarget.value !== '') {
      params.append('pageable_type', this.pageableTypeTarget.value)
    }
    
    if (this.hasHourOfDayTarget && this.hourOfDayTarget.value && this.hourOfDayTarget.value !== '') {
      params.append('hour_of_day', this.hourOfDayTarget.value)
    }
    
    if (this.hasDayOfWeekTarget && this.dayOfWeekTarget.value && this.dayOfWeekTarget.value !== '') {
      params.append('day_of_week', this.dayOfWeekTarget.value)
    }
    
    return params
  }

  // Reset all filters to default (empty)
  reset(event) {
    event.preventDefault()
    
    if (this.hasLocaleTarget) this.localeTarget.value = ''
    if (this.hasPageableTypeTarget) this.pageableTypeTarget.value = ''
    if (this.hasHourOfDayTarget) this.hourOfDayTarget.value = ''
    if (this.hasDayOfWeekTarget) this.dayOfWeekTarget.value = ''
    
    this.fetchData()
  }

  // Handle data updates from datetime filter
  handleDataUpdate(event) {
    // Only respond to events for our chart type
    if (event.detail.chartType !== this.chartTypeValue) return
    
    // Re-apply our filters when datetime changes
    this.fetchData()
  }

  // Set loading state on button
  setLoadingState(loading) {
    if (this.hasApplyButtonTarget) {
      this.applyButtonTarget.disabled = loading
    }
  }

  // Show error message
  showError(message) {
    // You can enhance this with a toast notification or modal
    console.error(message)
    alert(message)
  }

  // Get CSRF token for requests
  getCSRFToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta ? meta.content : ''
  }
}
