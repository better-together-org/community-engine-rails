import { Controller } from "@hotwired/stimulus";

// Bootstrap 5 Modal viewer for an image gallery. Thumbnails are the "trigger" buttons.
export default class extends Controller {
  static targets = ["trigger", "modal", "image", "caption", "counter"];
  static values = { counterTemplate: { type: String, default: "{current} / {total}" } };

  connect() {
    // Honour reduced motion by dropping the fade transition.
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) {
      this.modalTarget.classList.remove("fade");
    }
    this.index = 0;
    this.modal = new bootstrap.Modal(this.modalTarget);
    this.returnFocus = () => this.opener && this.opener.focus();
    this.modalTarget.addEventListener("hidden.bs.modal", this.returnFocus);
    this.touchStartX = null;
    this.imageTarget.addEventListener("touchstart", (e) => { this.touchStartX = e.changedTouches[0].clientX; }, { passive: true });
    this.imageTarget.addEventListener("touchend", (e) => this.swipe(e), { passive: true });
  }

  disconnect() {
    this.modalTarget.removeEventListener("hidden.bs.modal", this.returnFocus);
    if (this.modal) this.modal.dispose();
    this.modal = null;
  }

  open(event) {
    this.opener = event.currentTarget;
    this.show(this.triggerTargets.indexOf(this.opener));
    this.modal.show();
  }

  next() { this.show(this.index + 1); }

  previous() { this.show(this.index - 1); }

  keydown(event) {
    if (event.key === "ArrowRight") { event.preventDefault(); this.next(); }
    if (event.key === "ArrowLeft") { event.preventDefault(); this.previous(); }
  }

  swipe(event) {
    if (this.touchStartX === null) return;
    const delta = event.changedTouches[0].clientX - this.touchStartX;
    this.touchStartX = null;
    if (Math.abs(delta) < 50) return;
    delta < 0 ? this.next() : this.previous();
  }

  // Wraps around at both ends.
  show(index) {
    const total = this.triggerTargets.length;
    this.index = (index + total) % total;
    const trigger = this.triggerTargets[this.index];
    this.imageTarget.src = trigger.dataset.fullSrc;
    this.imageTarget.alt = trigger.dataset.alt || "";
    const caption = trigger.closest("figure").querySelector("figcaption");
    this.captionTarget.textContent = caption ? caption.textContent.trim() : "";
    this.counterTarget.textContent = this.counterTemplateValue
      .replace("{current}", this.index + 1)
      .replace("{total}", total);
    this.opener = trigger;
  }
}
