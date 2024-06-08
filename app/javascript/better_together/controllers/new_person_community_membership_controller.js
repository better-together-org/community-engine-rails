import { Controller } from "@hotwired/stimulus"
// import { get } from "@rails/request.js"

export default class extends Controller {
  static targets = ["modal", "sourceSelect"]

  connect() {
    // console.log("New BetterTogether::PersonCommunityMembership controller connected");
    this.modal = new bootstrap.Modal(this.modalTarget)
  }

  // Event handler for form submission
  submitForm(event) {
    event.preventDefault(); // Prevents the default form submission behavior
    const form = this.formTarget; // Retrieves the form target
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
      this.handleSuccess(); // Call the method to handle success
    }).catch(error => {
      console.error("Failed to submit:", error); // Logs any errors to the console
    });
  }

  // Method to close the modal dialog
  closeModal() {
    // const modal = new bootstrap.Modal(this.modalTarget); // Get a reference to the modal instance
    this.modal.hide(); // Hide the modal
  }

  // Method to open the modal dialog
  openModal() {
    // const modal = new bootstrap.Modal(this.modalTarget); // Get a reference to the modal instance
    this.modal.show(); // Show the modal
  }

  // Method to handle success of form submission
  handleSuccess() {
    this.closeModal(); // Close the modal on success
  }

  updateOptions() {
    const selectedValue = this.sourceSelectTarget.value;
    get(`/communities/${selectedValue}/update_member_select`, {
      responseKind: "turbo-stream"
    });
  }
}
