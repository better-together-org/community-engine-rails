// Stimulus controller for the event location picker. A single mixed-type
// SlimSelect field (see EventsController#available_locations) searches every
// Geography::Placeable type at once; on selection, the composite "ClassName:id"
// value is split back into the hidden location_id/location_type fields that
// LocatableLocation's polymorphic assignment already expects. Free-typed text
// with no match becomes the hidden `name` field (a "simple" location).
//
// The dropdown also offers "Create new address" and "Use my typed text" rows
// (slim_select_controller.js createOptions). Picking one dispatches
// better_together--slim-select:create, which this controller turns into either
// the inline address <fieldset> or a simple-name assignment.
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = [
    'locationSelect',
    'locationIdField',
    'locationTypeField',
    'simpleNameField',
    'newRecordBlock',
    'newRecordQuery',
    'cancelNewRecordButton',
    'announcement'
  ];

  static values = {
    // Populated from BetterTogether::Geography::Placeable.included_in_models so the
    // key -> class-name mapping can't drift from the Ruby allow-list. Used to
    // recognize a matched composite value's class-name prefix.
    locationTypeMap: Object,
    newRecordOpenedAnnouncement: String,
    newRecordCancelledAnnouncement: String
  };

  connect() {
    // A hidden new-record fieldset still POSTs ([hidden]/display:none does not
    // stop submission), so its fields are disabled unless the server rendered it
    // open - an error re-render carrying the user's typed address back.
    this.newRecordBlockTargets.forEach((block) => {
      const openOnLoad = !block.hasAttribute('hidden');
      this.toggleFieldsDisabled(block, !openOnLoad);
      if (openOnLoad) this.syncQueryCaption(block, block.dataset.newRecordQuery || '');
    });
  }

  // change on the picker select (dispatched by slim_select_controller afterChange).
  applyLocationSelection() {
    const value = this.hasLocationSelectTarget ? this.locationSelectTarget.value : '';

    if (!value) {
      this.clearStructuredLocationFields();
      this.clearSimpleLocationFields();
      return;
    }

    const matchedType = this.matchLocationType(value);
    if (matchedType) {
      this.setStructuredLocation(matchedType, value.slice(matchedType.length + 1));
    } else {
      this.setSimpleLocation(value);
    }

    // Picking a location supersedes any in-progress "+New" address.
    this.closeAllNewRecordBlocks();
    this.clearNewRecordInputs();
  }

  // better_together--slim-select:create - the user picked a "Create new X" or
  // "Use my typed text" row from the dropdown.
  revealNewRecord(event) {
    const detail = event.detail || {};
    const type = detail.type;
    const query = detail.query || '';

    if (type === 'simple') {
      this.applySimpleFromQuery(query);
      return;
    }

    const block = this.newRecordBlockTargets.find((el) => el.dataset.locationType === type);
    if (!block) return;

    // Clearing the picker fires applyLocationSelection (empty value), which also
    // closes and disables every new-record block - do it first, then open ours.
    this.resetPickerSelection();
    this.clearStructuredLocationFields();
    this.clearSimpleLocationFields();
    this.closeAllNewRecordBlocks();

    block.hidden = false;
    this.toggleFieldsDisabled(block, false);
    this.prefillFromQuery(block, query);
    this.syncQueryCaption(block, query);

    const firstField = block.querySelector(
      'input:not([type=hidden]):not([disabled]), select:not([disabled]), textarea:not([disabled])'
    );
    if (firstField) firstField.focus();

    this.announce(this.newRecordOpenedAnnouncementValue);
  }

  cancelNewRecord(event) {
    if (event) event.preventDefault();

    this.closeAllNewRecordBlocks();
    this.clearNewRecordInputs();
    this.clearStructuredLocationFields();
    this.clearSimpleLocationFields();
    this.resetPickerSelection();
    this.focusCombobox();
    this.announce(this.newRecordCancelledAnnouncementValue);
  }

  // "Use '<text>' as a custom location name" - no structured record, just the
  // hidden name field. SlimSelect cancelled its own selection of the sentinel row
  // (beforeChange returned false), so synthesize a matching <option> the way
  // slim_select_controller's afterChange does for AJAX results.
  applySimpleFromQuery(query) {
    const name = (query || '').trim();
    if (!name) return;

    this.setSimpleLocation(name);

    if (this.hasLocationSelectTarget) {
      const select = this.locationSelectTarget;
      const exists = Array.from(select.options).some((option) => option.value === name);
      if (!exists) select.add(new Option(name, name, false, false));
      select.value = name;
      select.dispatchEvent(new Event('change', { bubbles: true }));
    }

    this.closeAllNewRecordBlocks();
    this.clearNewRecordInputs();
  }

  // A real result's value is always "<one of locationTypeMapValue's class
  // names>:<id>" - checked against the allow-list rather than a bare ":"
  // heuristic, since free text could itself contain a colon.
  matchLocationType(value) {
    if (!this.hasLocationTypeMapValue) return null;

    return Object.values(this.locationTypeMapValue).find((className) => value.startsWith(`${className}:`)) || null;
  }

  setStructuredLocation(locationType, id) {
    if (this.hasLocationIdFieldTarget) this.locationIdFieldTarget.value = id;
    if (this.hasLocationTypeFieldTarget) this.locationTypeFieldTarget.value = locationType;
    this.clearSimpleLocationFields();
  }

  setSimpleLocation(name) {
    if (this.hasSimpleNameFieldTarget) this.simpleNameFieldTarget.value = name;
    this.clearStructuredLocationFields();
  }

  clearStructuredLocationFields() {
    if (this.hasLocationIdFieldTarget) this.locationIdFieldTarget.value = '';
    if (this.hasLocationTypeFieldTarget) this.locationTypeFieldTarget.value = '';
  }

  clearSimpleLocationFields() {
    if (this.hasSimpleNameFieldTarget) this.simpleNameFieldTarget.value = '';
  }

  toggleFieldsDisabled(target, disabled) {
    if (!target) return;
    target.querySelectorAll('input, select, textarea').forEach((field) => {
      field.disabled = disabled;
    });
  }

  closeAllNewRecordBlocks() {
    this.newRecordBlockTargets.forEach((block) => {
      block.hidden = true;
      this.toggleFieldsDisabled(block, true);
    });
  }

  clearNewRecordInputs() {
    this.newRecordBlockTargets.forEach((block) => {
      block.querySelectorAll('input, textarea').forEach((field) => {
        if (field.type === 'checkbox' || field.type === 'radio') {
          field.checked = field.defaultChecked;
        } else if (field.type !== 'hidden') {
          field.value = '';
        }
      });
      block.querySelectorAll('select').forEach((field) => {
        field.selectedIndex = 0;
      });
    });
  }

  prefillFromQuery(block, query) {
    const term = (query || '').trim();
    if (!term) return;
    const line1 = block.querySelector('input[name*="[line1]"]');
    if (line1 && !line1.value) line1.value = term;
  }

  syncQueryCaption(block, query) {
    const term = (query || '').trim();
    this.newRecordQueryTargets
      .filter((el) => block.contains(el))
      .forEach((el) => { el.textContent = term ? `"${term}"` : ''; });
  }

  // Ask slim_select_controller (createOptions selects only) to drop the current
  // selection. Falls back to nudging the native select directly.
  resetPickerSelection() {
    if (!this.hasLocationSelectTarget) return;
    this.locationSelectTarget.dispatchEvent(
      new CustomEvent('better_together--slim-select:reset-picker', { bubbles: false })
    );
  }

  focusCombobox() {
    const combobox = this.element.querySelector('.ss-main');
    if (combobox && typeof combobox.focus === 'function') combobox.focus();
  }

  announce(message) {
    if (!message || !this.hasAnnouncementTarget) return;
    this.announcementTarget.textContent = '';
    // Clear then set on the next tick so the live region re-announces even when
    // the message text repeats.
    setTimeout(() => { this.announcementTarget.textContent = message; }, 50);
  }
}
