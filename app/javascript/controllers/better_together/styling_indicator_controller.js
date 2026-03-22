import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["indicator"]

  connect() {
    this.checkStylingFields();
  }

  checkStylingFields() {
    const hasStyling = [...this.element.querySelectorAll('input, select')].some(input => input.value.trim() !== '');

    if (hasStyling) {
      this.indicatorTarget.classList.remove('d-none');
    } else {
      this.indicatorTarget.classList.add('d-none');
    }
  }

  handleInputChange() {
    this.checkStylingFields();
  }
}
