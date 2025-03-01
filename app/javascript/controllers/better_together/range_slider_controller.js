import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["output", "rangeField"];

  connect() {
    // Automatically bind the `input` event to the `update` method for the range input
    this.rangeFieldTarget.addEventListener('input', this.update.bind(this));

    // Initialize the display when the controller connects
    this.update();
  }

  update() {
    const value = this.rangeFieldTarget.value;
    const format = this.rangeFieldTarget.dataset.rangeSliderFormat;

    // Use the appropriate format to display the value
    if (format === "percentage") {
      this.outputTarget.textContent = `${(value * 100).toFixed(0)}%`;
    } else {
      this.outputTarget.textContent = value;
    }
  }
}
