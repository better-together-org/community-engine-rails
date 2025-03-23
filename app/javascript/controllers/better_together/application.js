import { Application } from "@hotwired/stimulus"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus   = application

console.log('community engine controllers application')

export { application }
