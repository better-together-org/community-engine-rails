import { Controller } from "@hotwired/stimulus"
import { createDebug } from "better_together/debugger"

// Base controller for all Better Together Stimulus controllers
// Provides common functionality like debug logging
export default class AppController extends Controller {
  initialize() {
    // Initialize debug logger for this controller
    // Uses the controller's identifier (e.g., 'better-together--time-zone')
    this.debug = createDebug(this.identifier, this.application)
  }
}
