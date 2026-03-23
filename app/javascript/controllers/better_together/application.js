import { Application } from "@hotwired/stimulus"
import { createDebug } from "better_together/debugger"

const application = Application.start()

// Configure Stimulus development experience
// Enable debug mode only if debug meta tag is present
const debugMeta = document.querySelector('meta[name="stimulus-debug"]')
application.debug = debugMeta && debugMeta.content === 'true'
window.Stimulus   = application

const debug = createDebug(application)
debug.log('[Stimulus] Community Engine controllers application started')

// Eager-load common helpers so they are available globally
import 'better_together/notifications'

export { application }
