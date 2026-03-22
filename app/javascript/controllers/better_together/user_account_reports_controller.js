import { Controller } from "@hotwired/stimulus";
import { createDebug } from "better_together/debugger";
import "channels/better_together/metrics/user_account_reports_channel";

/**
 * Stimulus controller for user account reports list
 */
export default class extends Controller {
  connect() {
    this.debug = createDebug(this.identifier, this.application);
    this.debug.log("User account reports controller connected");
  }

  disconnect() {
    if (this.debug) {
      this.debug.log("User account reports controller disconnected");
    }
  }
}
