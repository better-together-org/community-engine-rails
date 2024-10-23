// app/javascript/controllers/hero_scroll_indicator_controller.js
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["indicator"];

  connect() {
    console.log('hero scroll connected')
    this.checkHeight();
    window.addEventListener("resize", this.checkHeight.bind(this));
  }

  disconnect() {
    window.removeEventListener("resize", this.checkHeight.bind(this));
  }

  checkHeight() {
    const viewportHeight = window.innerHeight;
    const heroHeight = this.element.clientHeight;
    if (heroHeight === (viewportHeight - 56)) { // I subtract 56px from the hero vh to account for the navbar
      this.indicatorTarget.style.display = 'flex';
    }
  }
}
