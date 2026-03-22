// Stimulus controller for dynamic location selection in event forms
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "typeSelector",
    "simpleLocation", 
    "addressLocation",
    "buildingLocation",
    "addressTypeField",
    "buildingTypeField",
    "locationSelect",
    "buildingSelect",
    "newAddress",
    "newBuilding"
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

    // hide inline new blocks as well
    if (this.hasNewAddressTarget) this.newAddressTarget.style.display = 'none'
    if (this.hasNewBuildingTarget) this.newBuildingTarget.style.display = 'none'
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
    if (event && event.target && event.target.value && this.hasAddressTypeFieldTarget) {
      // keep hidden type field in sync if needed
      // nothing to do currently, but method preserved for future use
    }
  }

  updateBuildingType(event) {
    if (event && event.target && event.target.value && this.hasBuildingTypeFieldTarget) {
      // keep hidden type field in sync if needed
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

    // hide inline new blocks when switching
    if (this.hasNewAddressTarget) this.newAddressTarget.style.display = 'none'
    if (this.hasNewBuildingTarget) this.newBuildingTarget.style.display = 'none'
  }

  // Show inline new address fields
  showNewAddress(event) {
    event.preventDefault()
    if (this.hasNewAddressTarget) {
      this.newAddressTarget.style.display = this.newAddressTarget.style.display === 'none' ? 'block' : 'none'
      // focus first input inside the new address block for accessibility
      const focusable = this.newAddressTarget.querySelector('input, select, textarea')
      if (focusable) focusable.focus()
    }
  }

  // Show inline new building fields
  showNewBuilding(event) {
    event.preventDefault()
    if (this.hasNewBuildingTarget) {
      this.newBuildingTarget.style.display = this.newBuildingTarget.style.display === 'none' ? 'block' : 'none'
      const focusable = this.newBuildingTarget.querySelector('input, select, textarea')
      if (focusable) focusable.focus()
    }
  }
}
