// Stimulus controller for dynamic location selection in event forms
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "typeSelector",
    "simpleLocation", 
    "addressLocation",
    "buildingLocation",
    "addressTypeField",
    "buildingTypeField"
  ]

  connect() {
    // Initialize form state based on existing data
    this.updateVisibility()
  }

  toggleLocationType(event) {
    const selectedType = event.target.value
    this.hideAllLocationTypes()
    
    switch(selectedType) {
      case 'simple':
        this.showSimpleLocation()
        break
      case 'address':
        this.showAddressLocation()
        break
      case 'building':
        this.showBuildingLocation()
        break
    }
  }

  hideAllLocationTypes() {
    if (this.hasSimpleLocationTarget) {
      this.simpleLocationTarget.style.display = 'none'
    }
    if (this.hasAddressLocationTarget) {
      this.addressLocationTarget.style.display = 'none'
    }
    if (this.hasBuildingLocationTarget) {
      this.buildingLocationTarget.style.display = 'none'
    }
  }

  showSimpleLocation() {
    if (this.hasSimpleLocationTarget) {
      this.simpleLocationTarget.style.display = 'block'
    }
    // Clear structured location fields
    this.clearStructuredLocationFields()
  }

  showAddressLocation() {
    if (this.hasAddressLocationTarget) {
      this.addressLocationTarget.style.display = 'block'
    }
    // Clear simple name field
    this.clearSimpleLocationFields()
  }

  showBuildingLocation() {
    if (this.hasBuildingLocationTarget) {
      this.buildingLocationTarget.style.display = 'block'
    }
    // Clear simple name field
    this.clearSimpleLocationFields()
  }

  updateAddressType(event) {
    if (event.target.value && this.hasAddressTypeFieldTarget) {
      // Type field should already be set in the hidden field
    }
  }

  updateBuildingType(event) {
    if (event.target.value && this.hasBuildingTypeFieldTarget) {
      // Type field should already be set in the hidden field
    }
  }

  updateVisibility() {
    // Show the appropriate section based on current data
    const checkedRadio = this.element.querySelector('input[name="location_type_selector"]:checked')
    if (checkedRadio) {
      this.toggleLocationType({ target: { value: checkedRadio.value } })
    } else {
      // Default to simple location if nothing is selected
      this.hideAllLocationTypes()
      this.showSimpleLocation()
      const simpleRadio = this.element.querySelector('#simple_location')
      if (simpleRadio) {
        simpleRadio.checked = true
      }
    }
  }

  clearSimpleLocationFields() {
    const nameField = this.element.querySelector('input[name*="[name]"]')
    if (nameField) {
      nameField.value = ''
    }
  }

  clearStructuredLocationFields() {
    // Clear location_id and location_type for structured locations
    const locationIdFields = this.element.querySelectorAll('select[name*="[location_id]"]')
    locationIdFields.forEach(field => {
      field.selectedIndex = 0
    })
  }
}
