// app/javascript/better_together/controllers/conversation_messages_controller.js
import { Controller } from "@hotwired/stimulus"
// import { createConversationSubscription } from 'channels/better_together/conversations_channel'

export default class extends Controller {
  static values = {
    currentPersonId: String
  };

  connect() {
    this.scroll();
    this.observeMessages();
  }

  markMyMessages() {

  }

  scroll() {
    this.element.scrollTop = this.element.scrollHeight;
  }

  observeMessages() {
    const config = { childList: true };
    const callback = () => {
      // Scroll to bottom
      this.scroll();

      // Mark messages sent by current person
      Array.from(this.element.children).forEach(child => {
      if (child.dataset.senderId === this.currentPersonIdValue) {
        child.classList.add('me');
      } else {
        child.classList.remove('me');
      }
      });
    };

    this.observer = new MutationObserver(callback);
    this.observer.observe(this.element, config);
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}
