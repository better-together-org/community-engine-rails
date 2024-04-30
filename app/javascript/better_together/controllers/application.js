import { Application } from "@hotwired/stimulus"
import FlashController from "./flash_controller"
import ModalController from "./modal_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = false
window.Stimulus   = application

Stimulus.register('flash', FlashController)
Stimulus.register('modal', ModalController)

export { application }
