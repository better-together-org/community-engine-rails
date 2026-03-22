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
    // Validate all fields (including trix editors) via checkAllFields
    const allValid = this.checkAllFields();

    if (!allValid) {
      event.preventDefault();
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
    // Include trix-editor elements so checkValidity routes appropriately
    const fields = this.element.querySelectorAll("input, select, textarea, trix-editor");
    let allValid = true;
    fields.forEach(field => {
      const valid = this.checkValidity({ target: field });
      if (!valid) allValid = false;
    });
    return allValid;
  }

  checkValidity(event) {
    const field = event.target;

    // If the target is a trix-editor itself, or it's the hidden input
    // backing a trix-editor, route to the trix validity checker.
    let trixEditorElem = null;
    if (field && field.tagName && field.tagName.toLowerCase() === 'trix-editor') {
      trixEditorElem = field;
    } else if (field && field.tagName && field.tagName.toLowerCase() === 'input' && (field.type === 'hidden' || field.getAttribute('type') === 'hidden') && field.id) {
      trixEditorElem = this.element.querySelector(`trix-editor[input="${field.id}"]`);
    }

    if (trixEditorElem) {
      return this.checkTrixValidity({ target: trixEditorElem });
    }

    if (field.checkValidity && field.checkValidity() && field.value && field.value.trim() === "") {
      field.classList.remove("is-valid", "is-invalid");
      this.hideErrorMessage(field);
      return true;
    } else if (field.checkValidity && field.checkValidity()) {
      field.classList.remove("is-invalid");
      field.classList.add("is-valid");
      this.hideErrorMessage(field);
      return true;
    } else {
      if (field.classList) field.classList.add("is-invalid");
      this.showErrorMessage(field);
      return false;
    }
  }

  checkTrixValidity(event) {
    const editor = event.target;
    const field = editor.closest("trix-editor");
    const editorContent = (editor && editor.editor && typeof editor.editor.getDocument === 'function') ? editor.editor.getDocument().toString().trim() : (editor.textContent || '').trim();

    // Determine whether this trix-editor is required. We look for a required
    // attribute on the trix element itself or on the hidden input that backs
    // the trix editor (trix-editor has an "input" attribute referencing the
    // backing input's id). If it's not required, treat empty content as valid.
    let required = false;
    if (field) {
      const inputId = field.getAttribute('input');
      const hiddenInput = inputId ? this.element.querySelector(`#${inputId}`) : null;
      if (hiddenInput) {
        if (hiddenInput.required || hiddenInput.getAttribute('required') === 'true') required = true;
      }
      if (field.hasAttribute && (field.hasAttribute('required') || field.dataset.required === 'true')) required = true;
    }

    // If not required and empty, clear validation state and consider it valid
    if ((!required) && (!editorContent || editorContent === "")) {
      if (field && field.classList) {
        field.classList.remove("is-valid");
        field.classList.remove("is-invalid");
      }
      this.hideErrorMessage(field);
      return true;
    }

    // Non-empty content -> valid
    if (editorContent.length > 0) {
      if (field && field.classList) {
        field.classList.remove("is-invalid");
        field.classList.add("is-valid");
      }
      this.hideErrorMessage(field);
      return true;
    }

    // Fallback: mark invalid
    if (field && field.classList) field.classList.add("is-invalid");
    this.showErrorMessage(field);
    return false;
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
    // Trix editors may not place the invalid-feedback as the direct
    // next sibling; search for a nearby .invalid-feedback first.
    let errorMessage = field.nextElementSibling;
    if (!errorMessage || !errorMessage.classList.contains('invalid-feedback')) {
      // Try parent container
      errorMessage = field.parentElement && field.parentElement.querySelector('.invalid-feedback');
    }
    if (errorMessage && errorMessage.classList.contains('invalid-feedback')) {
      errorMessage.style.display = 'block';
    }
  }

  hideErrorMessage(field) {
    let errorMessage = field.nextElementSibling;
    if (!errorMessage || !errorMessage.classList.contains('invalid-feedback')) {
      errorMessage = field.parentElement && field.parentElement.querySelector('.invalid-feedback');
    }
    if (errorMessage && errorMessage.classList.contains('invalid-feedback')) {
      errorMessage.style.display = 'none';
    }
  }
}
