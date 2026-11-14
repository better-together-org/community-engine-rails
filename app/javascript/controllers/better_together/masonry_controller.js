import { Controller } from "@hotwired/stimulus";
import "masonry";
import "imagesloaded";

// Opt-in Masonry layout for image galleries. The default gallery layout is a plain CSS grid.
export default class extends Controller {
  static values = { itemSelector: { type: String, default: ".col" } };

  connect() {
    this.loader = imagesLoaded(this.element, () => {
      this.masonry = new Masonry(this.element, {
        itemSelector: this.itemSelectorValue,
        percentPosition: true,
        fitWidth: true,
      });
    });
  }

  disconnect() {
    if (this.masonry) this.masonry.destroy();
    this.masonry = null;
    this.loader = null;
  }
}
