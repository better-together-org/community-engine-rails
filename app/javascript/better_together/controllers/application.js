import { Application } from "@hotwired/stimulus"
import FlashController from "./flash_controller"
// import ModalController from "./modal_controller"
import NewPersonCommunityMembershipController from "./new_person_community_membership_controller"
import PersonCommunityMembershipController from "./person_community_membership_controller"

const application = Application.start()

// Configure Stimulus development experience
application.debug = true
window.Stimulus   = application

Stimulus.register('flash', FlashController)
// Stimulus.register('modal', ModalController)
Stimulus.register('bt-new-person-community-membership', NewPersonCommunityMembershipController)
Stimulus.register('bt-person-community-membership', PersonCommunityMembershipController)

export { application }
