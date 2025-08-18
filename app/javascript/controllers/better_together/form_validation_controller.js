import { Controller } from "@hotwired/stimulus";
import { Turbo } from "@hotwired/turbo-rails";

export default class extends Controller {
  static targets = ["input"];

  connect() {
    this.element.setAttribute("novalidate", true); // Disable default HTML5 validation
    // Cache bound handlers so we can remove them on disconnect
    this._onInput = this.checkValidity.bind(this);
    this._onChange = this.markFieldAsDirty.bind(this);
    this._onSubmit = this.handleFormSubmit.bind(this);
    this._onSubmitEnd = this.handleSubmitEnd.bind(this);
    this._onBeforeVisit = this.handleTurboNavigation.bind(this);
    this._onBeforeCache = this.handleBeforeCache?.bind(this) || this.handleBeforeCache.bind(this);
    this._onBeforeUnload = this.handleBeforeUnload.bind(this);

    this.element.addEventListener("input", this._onInput);

    this.isSubmitting = false; // Track form submission
    this.originalValues = new Map(); // Store initial field values
    this.dirtyFields = new Set(); // Track which fields have actually changed

    // Initialize original values for all fields
    this.storeInitialValues();

    // Listen for changes to mark fields dirty
    this.element.addEventListener("change", this._onChange);

    // Handle form submission
    this.element.addEventListener("submit", this._onSubmit);
    this.element.addEventListener("turbo:submit-end", this._onSubmitEnd);

    // Handle Turbo navigation (unsaved changes warning)
    document.addEventListener("turbo:before-visit", this._onBeforeVisit);
    // Clean up transient UI before Turbo caches the page
    document.addEventListener("turbo:before-cache", this._onBeforeCache);
    // Warn on full page unload if there are unsaved changes
    window.addEventListener("beforeunload", this._onBeforeUnload);
  }

  disconnect() {
    // Remove all listeners using the cached handler references
    if (this._onBeforeVisit) document.removeEventListener("turbo:before-visit", this._onBeforeVisit);
    if (this._onBeforeCache) document.removeEventListener("turbo:before-cache", this._onBeforeCache);
    if (this._onSubmitEnd) this.element.removeEventListener("turbo:submit-end", this._onSubmitEnd);
    if (this._onSubmit) this.element.removeEventListener("submit", this._onSubmit);
    if (this._onChange) this.element.removeEventListener("change", this._onChange);
    if (this._onInput) this.element.removeEventListener("input", this._onInput);
    if (this._onBeforeUnload) window.removeEventListener("beforeunload", this._onBeforeUnload);
  }

  storeInitialValues() {
    const fields = this.element.querySelectorAll("input, select, textarea");
    fields.forEach(field => {
      this.originalValues.set(field, this.getFieldValue(field));
    });
  }

  markFieldAsDirty(event) {
    const field = event.target;

    const original = this.originalValues.get(field);
    const current = this.getFieldValue(field);

    if (!this.valuesEqual(original, current)) {
      this.dirtyFields.add(field);
    } else {
      this.dirtyFields.delete(field);
    }
  }

  isFormDirty() {
    return this.dirtyFields.size > 0;
  }

  handleFormSubmit(event) {
    if (!this.element.checkValidity()) {
      event.preventDefault();
      this.checkAllFields();
      return;
    }

    // Prevent unsaved-changes prompt during form-driven navigation
    this.isSubmitting = true;
  }

  async handleSubmitEnd(event) {
    const { success, fetchResponse } = event.detail;

    if (!success && fetchResponse?.response.status === 422) {
      const html = await fetchResponse.responseHTML;
      Turbo.renderStreamMessage(html);
      this.isSubmitting = false;
    } else if (success) {
      this.resetValidation();
    }
  }

  handleTurboNavigation(event) {
    if (this.isFormDirty() && !this.isSubmitting) {
      const confirmation = confirm("You have unsaved changes. Are you sure you want to leave?");
      if (!confirmation) {
        event.preventDefault();
      }
    }
  }

  checkAllFields() {
    const fields = this.element.querySelectorAll("input, select, textarea");
    fields.forEach(field => this.checkValidity({ target: field }));
  }

  checkValidity(event) {
    const field = event.target;

    if (field.closest("trix-editor")) {
      return this.checkTrixValidity(event);
    }

    if (field.checkValidity() && field.value.trim() === "") {
      field.classList.remove("is-valid", "is-invalid");
      this.hideErrorMessage(field);
    } else if (field.checkValidity()) {
      field.classList.remove("is-invalid");
      field.classList.add("is-valid");
      this.hideErrorMessage(field);
    } else {
      field.classList.add("is-invalid");
      this.showErrorMessage(field);
    }
  }

  checkTrixValidity(event) {
    const editor = event.target;
    const field = editor.closest("trix-editor");
    const editorContent = editor.editor.getDocument().toString().trim();

    if (editorContent === "") {
      field.classList.remove("is-valid", "is-invalid");
      this.hideErrorMessage(field);
    } else if (editorContent.length > 0) {
      field.classList.remove("is-invalid");
      field.classList.add("is-valid");
      this.hideErrorMessage(field);
    } else {
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

    // Reset dirty state
    this.dirtyFields.clear();
    this.storeInitialValues(); // Re-store current values as "original"
  }

  // Normalize field value for dirty tracking
  getFieldValue(field) {
    const tag = field.tagName.toLowerCase();
    if (tag === "input") {
      const type = (field.getAttribute("type") || "text").toLowerCase();
      if (type === "checkbox" || type === "radio") {
        return field.checked;
      }
      return field.value;
    }
    if (tag === "select") {
      if (field.multiple) {
        return Array.from(field.options)
          .filter(o => o.selected)
          .map(o => o.value)
          .sort();
      }
      return field.value;
    }
    // textarea or others
    return field.value;
  }

  valuesEqual(a, b) {
    if (Array.isArray(a) && Array.isArray(b)) {
      if (a.length !== b.length) return false;
      for (let i = 0; i < a.length; i++) {
        if (a[i] !== b[i]) return false;
      }
      return true;
    }
    return a === b;
  }

  // Clear transient UI before Turbo caches the page
  handleBeforeCache() {
    this.resetValidation();
    this.isSubmitting = false;
  }

  // Show native prompt on hard reload/close if form is dirty
  handleBeforeUnload(event) {
    if (this.isFormDirty() && !this.isSubmitting) {
      event.preventDefault();
      event.returnValue = ""; // Required for Chrome to show prompt
      return ""; // For older browsers
    }
    return undefined;
  }

  showErrorMessage(field) {
    const errorMessage = field.nextElementSibling;
    if (errorMessage?.classList.contains("invalid-feedback")) {
      errorMessage.style.display = "block";
    }
  }

  hideErrorMessage(field) {
    const errorMessage = field.nextElementSibling;
    if (errorMessage?.classList.contains("invalid-feedback")) {
      errorMessage.style.display = "none";
    }
  }
}
