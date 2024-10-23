import { Controller } from '@hotwired/stimulus';
import 'slim-select';

export default class extends Controller {
  static values = {
    options: Object
  }

  connect() {
    this.slimSelect = new SlimSelect({
      select: this.element,
      settings: {
        allowDeselect: true
      },
      ...this.optionsValue
    });
  }

  disconnect() {
    if (this.slimSelect) {
      this.slimSelect.destroy();
    }
  }
}
