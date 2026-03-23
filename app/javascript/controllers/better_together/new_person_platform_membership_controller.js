import { Controller } from "@hotwired/stimulus"

// Defines a Stimulus controller for managing new PersonPlatformMembership creation
export default class extends Controller {
  // Targets that the controller interacts with
  static targets = ["modal"]

  // Lifecycle method called when the controller is connected to the DOM
  connect() {
    console.log("NewPersonPlatformMembership controller connected")
    
    // Add event listener for when modal is shown
    this.modalTarget.addEventListener('shown.bs.modal', () => {
      console.log("Modal shown, resetting form");
      this.resetForm();
    });
  }

  // Method to handle successful form submission
  handleSuccess(event) {
    console.log("HandleSuccess called with event:", event);
    console.log("Event detail:", event.detail);
    
    const xhr = event.detail && event.detail[2];
    
    // Check if xhr exists and has a response
    if (!xhr || !xhr.response) {
      console.log("No XHR response found, checking for successful turbo stream");
      // For turbo stream responses, we can check if the response was successful
      // by looking for specific turbo stream actions or just assume success if no errors
      this.closeModal();
      return;
    }

    // Check if the response contains form errors
    if (xhr.response.includes('form_errors')) {
      console.log("Form submission had errors")
      return
    }

    // Check if response contains turbo-stream (successful response)
    if (xhr.response.includes('turbo-stream')) {
      console.log("Turbo stream response detected, form submitted successfully")
      this.closeModal()
      return
    }

    console.log("Form submitted successfully")

    // Close the modal
    this.closeModal()
  }

  // Method to close the modal dialog
  closeModal() {
    // Reset the form before closing
    this.resetForm();
    
    // Find the Bootstrap modal instance and hide it
    const modal = bootstrap.Modal.getInstance(this.modalTarget)
    if (modal) {
      modal.hide()
    }
  }

  // Method to reset the form to its initial state
  resetForm() {
    const form = this.modalTarget.querySelector('form');
    if (form) {
      // Reset all form fields
      form.reset();
      
      // Reset any SlimSelect instances in the form
      const slimSelects = form.querySelectorAll('[data-controller*="slim-select"]');
      slimSelects.forEach(select => {
        // Clear the value
        select.value = '';
        // Trigger change event to update SlimSelect
        select.dispatchEvent(new Event('change', { bubbles: true }));
        // Clear any custom validation
        select.setCustomValidity('');
      });
      
      // Clear any error messages
      const errorContainer = form.querySelector('#form_errors');
      if (errorContainer) {
        errorContainer.innerHTML = '';
      }
    }
  }
}
