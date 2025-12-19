import { Controller } from "@hotwired/stimulus"

// Defines a Stimulus controller for managing new PersonPlatformMembership creation
export default class extends Controller {
  // Targets that the controller interacts with
  static targets = ["modal"]

  // Lifecycle method called when the controller is connected to the DOM
  connect() {
    console.log("NewPersonPlatformMembership controller connected")
  }

  // Method to handle successful form submission
  handleSuccess(event) {
    const [data, status, xhr] = event.detail
    
    // Check if the response contains form errors
    if (xhr.response.includes('form_errors')) {
      console.log("Form submission had errors")
      return
    }

    console.log("Form submitted successfully")
    
    // Close the modal
    this.closeModal()
  }

  // Method to close the modal dialog
  closeModal() {
    // Find the Bootstrap modal instance and hide it
    const modal = bootstrap.Modal.getInstance(this.modalTarget)
    if (modal) {
      modal.hide()
    }
  }
}
