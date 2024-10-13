import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hiddenInput", "toggle"]

  connect() {
    this.updateToggleState();
  }

  toggle() {
    if (this.toggleTarget.checked) {
      this.enableColorPicker();
    } else {
      this.disableColorPicker();
    }
  }

  enableColorPicker() {
    this.inputTarget.disabled = false;
    this.updateColor(); // Sync hidden input with the current color
  }

  disableColorPicker() {
    this.inputTarget.disabled = true;
    this.hiddenInputTarget.value = ''; // Clear the hidden input
  }

  updateColor() {
    if (this.toggleTarget.checked) {
      this.hiddenInputTarget.value = this.inputTarget.value; // Set hidden input to selected color
    }
  }

  updateToggleState() {
    if (this.hiddenInputTarget.value === '') {
      this.toggleTarget.checked = false;
      this.disableColorPicker();
    } else {
      this.toggleTarget.checked = true;
      this.enableColorPicker();
    }
  }
}
