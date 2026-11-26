// Ties a form's error summary to the fields it names, and moves focus to it when the page shows it.
//
// Each message may carry `data-field-id`; that field is marked aria-invalid and described by the message.
// A summary with no per-message ids describes the fields listed in its `fields` value instead.
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { fields: Array };

  connect() {
    this.element.querySelectorAll('[data-field-id]').forEach((message) => {
      this.mark(message.dataset.fieldId, message.id);
    });
    this.fieldsValue.forEach((id) => this.mark(id, this.element.id));
    this.element.focus({ preventScroll: false });
  }

  mark(fieldId, describedBy) {
    const field = document.getElementById(fieldId);
    if (!field || !describedBy) return;

    field.setAttribute('aria-invalid', 'true');
    const ids = new Set((field.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean));
    ids.add(describedBy);
    field.setAttribute('aria-describedby', [...ids].join(' '));
  }
}
