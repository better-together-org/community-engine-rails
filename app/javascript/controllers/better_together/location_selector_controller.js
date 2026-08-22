// Stimulus controller for the event location picker: a single mixed-type
// SlimSelect field searches every Geography::Placeable type at once (see
// EventsController#available_locations) and, on selection, splits the
// composite "ClassName:id" value back into the plain hidden location_id/
// location_type fields LocatableLocation's ordinary polymorphic assignment
// already expects - no change needed on the Ruby side of that assignment.
// Free-typed text with no match (SlimSelect's `addable` option, already
// implemented generically in slim_select_controller.js) falls into the
// hidden `name` field instead, matching a "simple" (unstructured) location.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "locationSelect",
    "locationIdField",
    "locationTypeField",
    "simpleNameField",
    "newRecordBlock",
    "newRecordButton"
  ]

  static values = {
    // Populated from the server (BetterTogether::Geography::Placeable.included_in_models)
    // rather than hardcoded here, so the key -> class-name mapping can't drift
    // from the Ruby-side allow-list. Used to recognize a matched composite
    // value's class-name prefix as a real Placeable type.
    locationTypeMap: Object
  }

  connect() {
    // "+New X" blocks start closed and, crucially, disabled - a hidden
    // block's fields still POST (display:none doesn't stop form submission)
    // and would collide with whichever location the picker actually holds
    // (e.g. Building's translatable name_en field submitted alongside a
    // picked Address, raising ActiveModel::UnknownAttributeError).
    this.newRecordBlockTargets.forEach((el) => this.toggleFieldsDisabled(el, true))
  }

  // Fires on the picker select's native `change` event (dispatched by
  // slim_select_controller's afterChange, after F1's fix ensures a matching
  // <option> - and therefore a real .value - exists for whatever was picked,
  // whether an AJAX search result or an addable-typed value).
  applyLocationSelection() {
    const value = this.hasLocationSelectTarget ? this.locationSelectTarget.value : ''

    if (!value) {
      this.clearStructuredLocationFields()
      this.clearSimpleLocationFields()
      return
    }

    const matchedType = this.matchLocationType(value)

    if (matchedType) {
      const id = value.slice(matchedType.length + 1)
      this.setStructuredLocation(matchedType, id)
    } else {
      this.setSimpleLocation(value)
    }

    // Picking an existing (or freshly typed simple) location supersedes any
    // in-progress "+New" build - close every block so its fields go back to
    // disabled and stop competing with the just-picked location on submit.
    this.closeAllNewRecordBlocks()
  }

  // A real result's value is always "<one of locationTypeMapValue's class
  // names>:<id>" (see EventsController#mixed_location_options) - checked
  // against the actual allow-list rather than a bare ":" heuristic, since
  // addable free text could itself contain a colon.
  matchLocationType(value) {
    if (!this.hasLocationTypeMapValue) return null

    return Object.values(this.locationTypeMapValue).find((className) => value.startsWith(`${className}:`)) || null
  }

  setStructuredLocation(locationType, id) {
    if (this.hasLocationIdFieldTarget) this.locationIdFieldTarget.value = id
    if (this.hasLocationTypeFieldTarget) this.locationTypeFieldTarget.value = locationType

    this.clearSimpleLocationFields()
  }

  setSimpleLocation(name) {
    if (this.hasSimpleNameFieldTarget) this.simpleNameFieldTarget.value = name

    this.clearStructuredLocationFields()
  }

  clearStructuredLocationFields() {
    if (this.hasLocationIdFieldTarget) this.locationIdFieldTarget.value = ''
    if (this.hasLocationTypeFieldTarget) this.locationTypeFieldTarget.value = ''
  }

  clearSimpleLocationFields() {
    if (this.hasSimpleNameFieldTarget) this.simpleNameFieldTarget.value = ''
  }

  toggleFieldsDisabled(target, disabled) {
    if (!target) return
    target.querySelectorAll('input, select, textarea').forEach((field) => {
      field.disabled = disabled
    })
  }

  closeAllNewRecordBlocks() {
    this.newRecordBlockTargets.forEach((el) => {
      el.style.display = 'none'
      this.toggleFieldsDisabled(el, true)
    })
  }

  // Shows/hides the inline "+New" fields block for the clicked button's
  // location type, matched via the shared data-location-type attribute.
  // Always available (server-gated only by Pundit policy(...).create? and by
  // Placeable#inline_creatable? - lookup-only types like Settlement/Region
  // never render a button at all) - independent of whatever the picker
  // currently holds, since a user reaches for "+New" precisely when nothing
  // in the search results is the location they want.
  showNewRecord(event) {
    event.preventDefault()
    const type = event.currentTarget.dataset.locationType
    const block = this.newRecordBlockTargets.find((el) => el.dataset.locationType === type)
    if (!block) return

    const opening = block.style.display === 'none'
    block.style.display = opening ? 'block' : 'none'
    this.toggleFieldsDisabled(block, !opening)
    // focus first input inside the new record block for accessibility
    if (opening) {
      const focusable = block.querySelector('input, select, textarea')
      if (focusable) focusable.focus()
    }
  }
}
