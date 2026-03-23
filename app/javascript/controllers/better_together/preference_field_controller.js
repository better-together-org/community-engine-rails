// app/javascript/controllers/better_together/preference_field_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "toolbar", "saveButton", "cancelButton"]
  static values = { 
    originalValue: String,
    url: String,
    fieldName: String
  }

  connect() {
    this.hideToolbar()
    this.storeOriginalValue()
  }

  storeOriginalValue() {
    const field = this.fieldTarget
    if (field.type === 'checkbox') {
      this.originalValueValue = field.checked.toString()
    } else {
      this.originalValueValue = field.value
    }
  }

  fieldChanged() {
    const currentValue = this.getCurrentValue()
    const hasChanges = currentValue !== this.originalValueValue
    
    if (hasChanges) {
      this.showToolbar()
    } else {
      this.hideToolbar()
    }
  }

  getCurrentValue() {
    const field = this.fieldTarget
    if (field.type === 'checkbox') {
      return field.checked.toString()
    }
    return field.value
  }

  showToolbar() {
    this.toolbarTarget.style.visibility = 'visible'
  }

  hideToolbar() {
    this.toolbarTarget.style.visibility = 'hidden'
  }

  cancel(event) {
    event.preventDefault()
    
    const field = this.fieldTarget
    if (field.type === 'checkbox') {
      field.checked = this.originalValueValue === 'true'
    } else {
      field.value = this.originalValueValue
    }
    
    this.hideToolbar()
  }

  async save(event) {
    event.preventDefault()
    
    const formData = new FormData()
    const field = this.fieldTarget
    const value = field.type === 'checkbox' ? field.checked : field.value
    
    // Build nested params: person[locale]=en
    formData.append(`person[${this.fieldNameValue}]`, value)
    
    this.setSaving(true)
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'PATCH',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (response.ok) {
        const data = await response.json()
        this.handleSuccess(data)
      } else {
        const data = await response.json()
        this.handleError(data)
      }
    } catch (error) {
      console.error('Error saving preference:', error)
      this.handleError({ error: error.message })
    } finally {
      this.setSaving(false)
    }
  }

  handleSuccess(data) {
    // Update original value to current value
    this.storeOriginalValue()
    this.hideToolbar()
    
    // Show success flash message
    this.showFlash('success', data.message || 'Preference saved successfully')
  }

  handleError(data) {
    // Show error flash message
    const message = data.errors ? Object.values(data.errors).flat().join(', ') : 'Failed to save preference'
    this.showFlash('alert', message)
  }

  showFlash(type, message) {
    // Dispatch custom event for flash message display
    const event = new CustomEvent('preference:flash', {
      detail: { type, message },
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }

  setSaving(isSaving) {
    this.saveButtonTarget.disabled = isSaving
    this.cancelButtonTarget.disabled = isSaving
    
    if (isSaving) {
      this.saveButtonTarget.innerHTML = '<span class="spinner-border spinner-border-sm me-1"></span>Saving...'
    } else {
      this.saveButtonTarget.innerHTML = '<i class="fa-solid fa-check me-1"></i>Save'
    }
  }
}
