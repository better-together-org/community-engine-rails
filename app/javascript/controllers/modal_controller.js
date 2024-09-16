import { Controller } from "@hotwired/stimulus"
// import { Modal } from "bootstrap"

export default class extends Controller {
  static targets = ["modal", "add-btn"]

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget)
  }

  open() {
    this.modal.show()
  }

  close() {
    this.modal.hide()
  }

  handleSuccess(event) {
    this.close();
    // Trigger any additional UI update or notification here if needed
  }

}
