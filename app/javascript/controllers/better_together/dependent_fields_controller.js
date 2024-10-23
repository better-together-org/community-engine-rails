// app/javascript/controllers/dependent_fields_controller.js

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["controlField", "dependentField"]

  connect() {
    this.toggleFields(); // Initial check to set the correct state
    this.setupListeners(); // Set up event listeners for input types
  }

  setupListeners() {
    this.controlFieldTargets.forEach(controlField => {
      if (controlField.tagName === "SELECT") {
        controlField.addEventListener("change", this.toggleFields.bind(this));
      } else if (controlField.type === "checkbox" || controlField.type === "radio") {
        controlField.addEventListener("change", this.toggleFields.bind(this));
      } else {
        controlField.addEventListener("input", this.toggleFields.bind(this));
      }
    });
  }

  toggleFields() {
    this.controlFieldTargets.forEach(controlField => {
      const valueSet = controlField.value !== null && controlField.value !== ""; // Check if any value is set

      this.dependentFieldTargets.forEach(field => {
        const showIfValue = field.dataset.showIfValue;

        if (
          (showIfValue === "*present*" && valueSet) ||  // Show field if *present* and a value is set
          (showIfValue === "*not_present*" && !valueSet) || // Show field if *not_present* and no value is set
          (showIfValue === controlField.value) // Or show field if specific value matches
        ) {
          field.classList.add('visible-field'); // Show the field
          field.classList.remove('hidden-field');
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = false);
        } else {
          field.classList.add('hidden-field'); // Hide the field
          field.classList.remove('visible-field');
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = true);
        }
      });
    });
  }
}
