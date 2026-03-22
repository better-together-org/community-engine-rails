import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
// Enable debug mode only if debug meta tag is present
const debugMeta = document.querySelector('meta[name="stimulus-debug"]')
application.debug = debugMeta && debugMeta.content === 'true'
window.Stimulus   = application


export { application }
