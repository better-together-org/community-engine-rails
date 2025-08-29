import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus   = application

console.log('community engine controllers application')

// Eager-load common helpers so they are available globally
import 'better_together/notifications'

export { application }
