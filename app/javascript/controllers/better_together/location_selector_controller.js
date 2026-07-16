// Stimulus controller for dynamic location selection in event forms
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "typeSelector",
    "simpleLocation",
    "structuredLocation",
    "locationTypeField",
    "locationIdSelect",
    "newAddress",
    "newBuilding",
    "newAddressButton",
    "newBuildingButton"
  ]

  static values = {
    // Populated from the server (BetterTogether::Geography::Placeable.included_in_models)
    // rather than hardcoded here, so the radio-value -> class-name mapping can't drift
    // from the Ruby-side allow-list.
    locationTypeMap: Object,
    availableLocationsUrl: String
  }

  connect() {
    // Initialize form state based on existing data
    this.updateVisibility()
  }

  toggleLocationType(event) {
    const selectedType = event.target.value
    this.hideAllLocationTypes()

    if (selectedType === 'simple') {
      this.showSimpleLocation()
    } else {
      this.showStructuredLocation(selectedType)
    }
  }

  hideAllLocationTypes() {
    if (this.hasSimpleLocationTarget) {
      this.simpleLocationTarget.style.display = 'none'
    }
    if (this.hasStructuredLocationTarget) {
      this.structuredLocationTarget.style.display = 'none'
    }

    // hide inline new blocks and their trigger buttons as well
    if (this.hasNewAddressTarget) this.newAddressTarget.style.display = 'none'
    if (this.hasNewBuildingTarget) this.newBuildingTarget.style.display = 'none'
    if (this.hasNewAddressButtonTarget) this.newAddressButtonTarget.style.display = 'none'
    if (this.hasNewBuildingButtonTarget) this.newBuildingButtonTarget.style.display = 'none'

    // The "+New" address/building blocks both nest fields_for :location for the
    // SAME location association. A hidden block's fields still POST (display:none
    // doesn't stop form submission) and collide with whichever type is actually
    // selected — e.g. Building's translatable name_en field getting submitted
    // alongside an Address, raising ActiveModel::UnknownAttributeError. Disabled
    // fields are excluded from form submission, so keep both disabled whenever
    // neither is the active, opened type.
    this.toggleFieldsDisabled(this.hasNewAddressTarget ? this.newAddressTarget : null, true)
    this.toggleFieldsDisabled(this.hasNewBuildingTarget ? this.newBuildingTarget : null, true)
  }

  toggleFieldsDisabled(target, disabled) {
    if (!target) return
    target.querySelectorAll('input, select, textarea').forEach((field) => {
      field.disabled = disabled
    })
  }

  showSimpleLocation() {
    if (this.hasSimpleLocationTarget) {
      this.simpleLocationTarget.style.display = 'block'
    }
    // Clear structured location fields
    this.clearStructuredLocationFields()
  }

  // Shows the single unified location_id select and points its SlimSelect
  // AJAX source at #available_locations for the selected radio's mapped class.
  showStructuredLocation(selectedType) {
    if (this.hasStructuredLocationTarget) {
      this.structuredLocationTarget.style.display = 'block'
    }
    // Clear simple name field
    this.clearSimpleLocationFields()

    const locationType = this.hasLocationTypeMapValue ? this.locationTypeMapValue[selectedType] : null
    if (!locationType) return

    if (this.hasLocationTypeFieldTarget) {
      this.locationTypeFieldTarget.value = locationType
    }

    this.updateLocationSelectSource(locationType)

    // Only address/building support inline "+New" creation; settlement/region
    // are curated reference data, lookup-only by design. The trigger buttons
    // are server-gated by Pundit (rendered only when policy(...).create? is
    // true) but hidden/shown here based on the currently selected radio,
    // since the server only knows the type at initial render, not after the
    // user switches radios client-side.
    if (this.hasNewAddressButtonTarget) {
      this.newAddressButtonTarget.style.display = selectedType === 'address' ? 'inline-block' : 'none'
    }
    if (this.hasNewBuildingButtonTarget) {
      this.newBuildingButtonTarget.style.display = selectedType === 'building' ? 'inline-block' : 'none'
    }
    if (selectedType !== 'address' && this.hasNewAddressTarget) {
      this.newAddressTarget.style.display = 'none'
      this.toggleFieldsDisabled(this.newAddressTarget, true)
    }
    if (selectedType !== 'building' && this.hasNewBuildingTarget) {
      this.newBuildingTarget.style.display = 'none'
      this.toggleFieldsDisabled(this.newBuildingTarget, true)
    }
  }

  // Rewrites the location_id select's slim-select options data attribute with
  // a fresh ajax.url for the given location_type — this DOM mutation is what
  // slim_select_controller's optionsValueChanged callback reacts to, tearing
  // down and reinitializing SlimSelect against the new AJAX source. The
  // attribute name must match slim_select_controller's own canonical Values
  // API name for its `options` value (data-<controller-identifier>-options-value,
  // using the identifier exactly as declared in data-controller — underscore,
  // not hyphen) or Stimulus never observes the mutation and this silently no-ops.
  updateLocationSelectSource(locationType) {
    if (!this.hasLocationIdSelectTarget || !this.hasAvailableLocationsUrlValue) return

    const url = new URL(this.availableLocationsUrlValue, window.location.origin)
    url.searchParams.set('location_type', locationType)

    const optionsValue = JSON.stringify({ ajax: { url: url.pathname + url.search } })
    this.locationIdSelectTarget.setAttribute('data-better_together--slim-select-options-value', optionsValue)
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
    // Clear location_id and location_type for the unified structured location fields
    if (this.hasLocationIdSelectTarget) {
      this.locationIdSelectTarget.selectedIndex = 0
    }
    if (this.hasLocationTypeFieldTarget) {
      this.locationTypeFieldTarget.value = ''
    }

    // hide inline new blocks when switching
    if (this.hasNewAddressTarget) this.newAddressTarget.style.display = 'none'
    if (this.hasNewBuildingTarget) this.newBuildingTarget.style.display = 'none'
    this.toggleFieldsDisabled(this.hasNewAddressTarget ? this.newAddressTarget : null, true)
    this.toggleFieldsDisabled(this.hasNewBuildingTarget ? this.newBuildingTarget : null, true)
  }

  // Show inline new address fields
  showNewAddress(event) {
    event.preventDefault()
    if (this.hasNewAddressTarget) {
      const opening = this.newAddressTarget.style.display === 'none'
      this.newAddressTarget.style.display = opening ? 'block' : 'none'
      this.toggleFieldsDisabled(this.newAddressTarget, !opening)
      // focus first input inside the new address block for accessibility
      if (opening) {
        const focusable = this.newAddressTarget.querySelector('input, select, textarea')
        if (focusable) focusable.focus()
      }
    }
  }

  // Show inline new building fields
  showNewBuilding(event) {
    event.preventDefault()
    if (this.hasNewBuildingTarget) {
      const opening = this.newBuildingTarget.style.display === 'none'
      this.newBuildingTarget.style.display = opening ? 'block' : 'none'
      this.toggleFieldsDisabled(this.newBuildingTarget, !opening)
      if (opening) {
        const focusable = this.newBuildingTarget.querySelector('input, select, textarea')
        if (focusable) focusable.focus()
      }
    }
  }
}
