import { Controller } from "@hotwired/stimulus"

// Scrolls newly-broadcast comments into view as they're appended by the
// turbo_stream_from(commentable) subscription — mirrors conversation_messages_controller.js.
export default class extends Controller {
  connect() {
    this.observeComments();
  }

  observeComments() {
    const callback = (mutations) => {
      const added = mutations.flatMap(mutation => Array.from(mutation.addedNodes));
      const lastAdded = added[added.length - 1];
      if (lastAdded && lastAdded.scrollIntoView) {
        lastAdded.scrollIntoView({ behavior: "smooth", block: "nearest" });
      }
    };

    this.observer = new MutationObserver(callback);
    this.observer.observe(this.element, { childList: true });
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}
