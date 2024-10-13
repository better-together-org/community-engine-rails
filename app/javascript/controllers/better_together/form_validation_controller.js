import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"]; // Add Trix as a target

  connect() {
    this.element.setAttribute("novalidate", true); // Disable default HTML5 validation
    this.element.addEventListener("input", this.checkValidity.bind(this));

    // Track whether the form has been changed
    this.isDirty = false;
    this.isSubmitting = false; // Flag to track form submission

    // Listen for changes in the form to track unsaved changes
    this.element.addEventListener("change", this.markAsDirty.bind(this));

    // Handle form submission to avoid triggering the dirty state warning
    this.element.addEventListener("submit", this.handleFormSubmit.bind(this));

    // Handle Turbo navigation events
    document.addEventListener("turbo:before-visit", this.handleTurboNavigation.bind(this));
  }

  disconnect() {
    // Clean up the Turbo event listener
    document.removeEventListener("turbo:before-visit", this.handleTurboNavigation.bind(this));
  }

  markAsDirty() {
    this.isDirty = true; // Mark the form as "dirty" (changed)
  }

  handleFormSubmit(event) {
    // Check if the form is valid before submission
    if (!this.element.checkValidity()) {
      event.preventDefault(); // Prevent form submission
      this.checkAllFields(); // Manually validate all fields
      return;
    }
    
    this.isSubmitting = true; // Mark the form as being submitted to prevent warning
  }

  handleTurboNavigation(event) {
    // Only show the unsaved changes warning if the form is dirty and not currently submitting
    if (this.isDirty && !this.isSubmitting) {
      const confirmation = confirm("You have unsaved changes. Are you sure you want to leave?");
      if (!confirmation) {
        event.preventDefault(); // Prevent Turbo from navigating if the user cancels
      }
    }
  }

  // Add a method to check all fields
  checkAllFields() {
    const fields = this.element.querySelectorAll("input, select, textarea");
    fields.forEach(field => {
      this.checkValidity({ target: field });
    });
  }

  checkValidity(event) {
    const field = event.target;

    // Skip validation for Trix hidden input fields
    if (field.closest("trix-editor")) return this.checkTrixValidity(event);

    // If field is valid but empty, remove validation classes
    if (field.checkValidity() && field.value.trim() === "") {
      field.classList.remove("is-valid", "is-invalid");
      this.hideErrorMessage(field);
    } 
    // If field is valid and not empty, apply valid state
    else if (field.checkValidity()) {
      field.classList.remove("is-invalid");
      field.classList.add("is-valid");
      this.hideErrorMessage(field);
    } 
    // If field is invalid, apply invalid state
    else {
      field.classList.add("is-invalid");
      this.showErrorMessage(field);
    }
  }

  checkTrixValidity(event) {
    const editor = event.target;
    const field = editor.closest("trix-editor");

    const editorContent = editor.editor.getDocument().toString().trim();

    // If Trix content is empty, remove validation classes
    if (editorContent === "") {
      field.classList.remove("is-valid", "is-invalid");
      this.hideErrorMessage(field);
    } 
    // If Trix content is not empty, apply valid state
    else if (editorContent.length > 0) {
      field.classList.remove("is-invalid");
      field.classList.add("is-valid");
      this.hideErrorMessage(field);
    } 
    // If Trix content is considered invalid (you can define conditions here)
    else {
      field.classList.add("is-invalid");
      this.showErrorMessage(field);
    }
  }

  resetValidation() {
    const fields = this.element.querySelectorAll(".is-invalid, .is-valid");
    fields.forEach(field => {
      field.classList.remove("is-invalid", "is-valid");
      this.hideErrorMessage(field);
    });
  }

  showErrorMessage(field) {
    const errorMessage = field.nextElementSibling;
    if (errorMessage && errorMessage.classList.contains("invalid-feedback")) {
      errorMessage.style.display = "block";
    }
  }

  hideErrorMessage(field) {
    const errorMessage = field.nextElementSibling;
    if (errorMessage && errorMessage.classList.contains("invalid-feedback")) {
      errorMessage.style.display = "none";
    }
  }
}
