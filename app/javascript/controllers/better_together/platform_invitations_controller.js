import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

// Defines a Stimulus controller for managing PlatformInvitation entities
export default class extends Controller {
  // Targets that the controller interacts with
  static targets = ["newInvitationModal", "errors", "table"]

  // Lifecycle method called when the controller is connected to the DOM
  connect() {
    console.log("BetterTogether::PlatformInvitation controller connected");
  }

  // Method to handle success of form submission
  handleInviteSuccess(event) {
    console.log('success?', event.detail.success)
    // this.closeNewInvitationModal(); // Close the modal on success
  }

  // Event handler for form submission
  submitForm(event) {
    event.preventDefault(); // Prevents the default form submission behavior

    const form = event.target.closest('form'); // Retrieves the form element from the event
    const formData = new FormData(form); // Wraps form inputs in a FormData object for fetch

    // Sends the form data to the server using fetch API
    fetch(form.action, {
      method: form.method,
      body: formData,
      dataType: "json",
      headers: {
        "Accept": "text/vnd.turbo-stream.html", // Specifies that Turbo Streams are expected in response
      }
    }).then(response => {
      if (response.ok) {
        return response.text(); // Returns response text if the fetch was successful
      } else {
        throw new Error('Network response was not ok');
      }
    }).then(html => {
      Turbo.renderStreamMessage(html); // Renders the Turbo Stream update to the DOM
      if (!html.includes('form_errors')) {
        this.closeNewInvitationModal(); // Closes the modal on success
      }
    }).catch(error => {
      console.error("Failed to submit:", error); // Logs any errors to the console
    });
  }

  // Method to close the modal dialog
  closeNewInvitationModal() {
    this.modal.hide(); // Hide the modal
  }

  // Method to open the modal dialog
  openNewInvitationModal() {
    this.modal = new bootstrap.Modal(this.newInvitationModalTarget); // Get a reference to the modal instance
    this.modal.show(); // Show the modal
  }

  // Method to confirm the deletion of a member
  confirmDelete(event) {
    if (!confirm("Are you sure you want to delete this invitation?")) {
      event.preventDefault(); // Prevents the default action if the user cancels the deletion
    }
  }

  // Displays form errors dynamically in the designated errors area
  displayErrors([data]) {
    const [content, status] = data.detail;
    if (status === 422) { // Checks if the status code is 422 Unprocessable Entity
      this.errorsTarget.innerHTML = content; // Updates the errors target with the error content
    }
  }
}
