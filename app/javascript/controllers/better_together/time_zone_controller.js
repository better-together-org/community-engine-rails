import { Controller } from "stimulus"

export default class extends Controller {
  static targets = [ "select" ]

  connect() {
    // Called when the controller is initialized and the element is in the DOM
    const userTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;

    if (this.hasSelectTarget) {
      const options = this.selectTarget.options;
      for (let i = 0; i < options.length; i++) {
        if (options[i].value === userTimeZone) {
          this.selectTarget.selectedIndex = i;
          break;
        }
      }
    }
  }
}
