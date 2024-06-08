
import { Application } from "@hotwired/stimulus"
import FlashController from "./flash_controller"
// import ModalController from "./modal_controller"
import DynamicSelectController from "./dynamic_select_controller"
import NewPersonCommunityMembershipController from "./new_person_community_membership_controller"
import PersonCommunityMembershipController from "./person_community_membership_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus   = application

console.log('start application')

Stimulus.register('flash', FlashController)
// Stimulus.register('modal', ModalController)
Stimulus.register('bt-dynamic-select', DynamicSelectController)
Stimulus.register('bt-new-person-community-membership', NewPersonCommunityMembershipController)
Stimulus.register('bt-person-community-membership', PersonCommunityMembershipController)

// Lazy load controllers as they appear in the DOM (remember not to preload controllers in import map!)
import { lazyLoadControllersFrom } from 'stimulus-loading' // Adjust the path if necessary
lazyLoadControllersFrom("controllers", application)

console.log('initializing engine controllers')

export { application }
