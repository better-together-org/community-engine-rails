// app/javascript/better_together/controllers/conversation_messages_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.scroll();
    this.observeMessages();
  }

  scroll() {
    this.element.scrollTop = this.element.scrollHeight;
  }

  observeMessages() {
    const config = { childList: true };
    const callback = () => this.scroll();

    this.observer = new MutationObserver(callback);
    this.observer.observe(this.element, config);
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}
