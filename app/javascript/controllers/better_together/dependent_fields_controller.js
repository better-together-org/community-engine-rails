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
    const controlFieldCount = this.controlFieldTargets.length; // Count the control fields

    this.dependentFieldTargets.forEach(field => {
      const controlFieldIds = field.dataset.dependentFieldsControl?.split(" "); // Get the control field IDs

      if (controlFieldIds && controlFieldIds.length > 0) {
        // If there are multiple control fields
        const allConditionsMet = controlFieldIds.every(controlFieldId => {
          const controlField = document.getElementById(controlFieldId.trim()); // Find control field by ID
          const showIfValue = field.dataset[`showIfControl_${controlFieldId.trim()}`]; // Get showIfValue for this control field

          if (!controlField) {
            console.error(`Error: Control field with ID '${controlFieldId}' not found.`);
            return false;
          }

          const valueSet = controlField.value !== null && controlField.value !== ""; // Check if any value is set

          return (
            (showIfValue === "*present*" && valueSet) ||  // Show field if *present* and a value is set
            (showIfValue === "*not_present*" && !valueSet) || // Show field if *not_present* and no value is set
            (showIfValue === controlField.value) // Or show field if specific value matches
          );
        });

        if (allConditionsMet) {
          field.classList.remove('hidden-field'); // Show the field
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = false);
        } else {
          field.classList.add('hidden-field'); // Hide the field
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = true);
        }
      } else if (controlFieldCount === 1) {
        // Backward compatibility: Use the single control field if only one is present
        const controlField = this.controlFieldTargets[0];
        const valueSet = controlField.value !== null && controlField.value !== ""; // Check if any value is set
        const showIfValue = field.dataset.showIfValue; // Use the original showIfValue syntax
        const showUnlessValue = field.dataset.showUnlessValue; // Use the original showUnlessValue syntax

        let showDependent = false;

        if (showIfValue) {
          showDependent = (showIfValue === "*present*" && valueSet) ||
          (showIfValue === "*not_present*" && !valueSet) ||
          (showIfValue === controlField.value)
        } else {
          showDependent = (showUnlessValue === "*present*" && !valueSet) ||
          (showUnlessValue === "*not_present*" && valueSet) ||
          (showUnlessValue != controlField.value)
        }

        if (
          showDependent
        ) {
          field.classList.remove('hidden-field'); // Show the field
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = false);
        } else {
          field.classList.add('hidden-field'); // Hide the field
          field.querySelectorAll('input, select, textarea').forEach(input => input.disabled = true);
        }
      } else if (controlFieldCount > 1) {
        console.error(`Error: Multiple control fields found, but no 'data-dependent-fields-control' specified for the dependent field:`, field);
      }
    });
  }
}
