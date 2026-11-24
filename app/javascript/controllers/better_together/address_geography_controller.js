// Cascading country / state / settlement selects for the address form.
//
// Each level is a SlimSelect over LocationsController#geography. Picking a record sets that level's
// hidden *_id field (the server then overwrites the matching string column with the record's name).
// Choosing "Use <typed text>" clears the id and puts the text into the string column instead, so a
// place that is not a geography record yet can still be entered. A parent change clears the levels
// below it, since their choices were narrowed by it.
import { Controller } from '@hotwired/stimulus';

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const LEVELS = ['country', 'state', 'settlement'];

export default class extends Controller {
  static targets = [
    'countrySelect', 'countryId', 'countryName',
    'stateSelect', 'stateId', 'stateName',
    'settlementSelect', 'settlementId', 'settlementName'
  ];

  // change on a level's select (dispatched by slim_select_controller).
  select(event) {
    const level = event.params.level;
    const select = this[`${level}SelectTarget`];
    const value = select.value;
    const idField = this[`${level}IdTarget`];
    const nameField = this[`${level}NameTarget`];
    const previousId = idField.value;

    if (!value) {
      idField.value = '';
      // Keep any text the user typed earlier only when it came from a typed entry.
      if (previousId) nameField.value = '';
    } else if (UUID.test(value)) {
      idField.value = value;
      const option = select.selectedOptions[0];
      if (option) nameField.value = option.textContent.trim();
    } else {
      idField.value = '';
      nameField.value = value;
    }

    if (idField.value !== previousId) this.resetBelow(level);
  }

  resetBelow(level) {
    LEVELS.slice(LEVELS.indexOf(level) + 1).forEach((lower) => {
      const select = this[`${lower}SelectTarget`];
      this[`${lower}IdTarget`].value = '';
      this[`${lower}NameTarget`].value = '';
      select.dispatchEvent(new CustomEvent('better_together--slim-select:reset-picker', { bubbles: false }));
    });
  }
}
