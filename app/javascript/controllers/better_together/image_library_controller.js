import { Controller } from "@hotwired/stimulus"
// import { Modal } from "bootstrap"

export default class extends Controller {
  static targets = ["modal", "signedIdField"]

  connect() {
    this.modal = new bootstrap.Modal(this.modalTarget)
  }

  open() {
    this.modal.show()
  }

  select(event) {
    const { signedId, url } = event.currentTarget.dataset
    this.signedIdFieldTarget.value = signedId
    const previewController = this.application.getControllerForElementAndIdentifier(this.element, "better_together--image-preview")
    if (previewController && typeof previewController.previewFromUrl === "function") {
      previewController.previewFromUrl(url)
    }
    this.modal.hide()
  }
}
