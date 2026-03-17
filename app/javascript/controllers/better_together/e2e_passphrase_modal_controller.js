import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "input"]

  #resolve   = null
  #modal     = null
  #showInput = false

  connect() {
    document.addEventListener('e2e:request-passphrase', this.#onRequest)
    document.addEventListener('e2e:request-confirm',    this.#onRequest)
    this.#modal = new window.bootstrap.Modal(this.element)
    this.element.addEventListener('hidden.bs.modal', this.onDismiss)
  }

  disconnect() {
    document.removeEventListener('e2e:request-passphrase', this.#onRequest)
    document.removeEventListener('e2e:request-confirm',    this.#onRequest)
    this.element.removeEventListener('hidden.bs.modal', this.onDismiss)
  }

  submit() {
    // Use #showInput (set in #onRequest) rather than hasInputTarget:
    // the input target always exists in the DOM (hidden via CSS for confirm flows),
    // so hasInputTarget is always true and would never resolve `true` for confirms.
    const value = this.#showInput ? (this.inputTarget.value.trim() || null) : true
    this.#resolve?.(value)
    this.#resolve = null
    this.#modal.hide()
  }

  cancel() {
    this.#resolve?.(null)
    this.#resolve = null
    this.#modal.hide()
  }

  #onRequest = (event) => {
    const { message, showInput, minLength, resolve } = event.detail
    this.#showInput = !!showInput
    this.messageTarget.textContent = message
    if (this.hasInputTarget) {
      this.inputTarget.value = ''
      this.inputTarget.style.display = showInput ? '' : 'none'
      this.inputTarget.minLength = minLength ?? 0
    }
    this.#resolve = resolve
    this.#modal.show()
  }

  // Public so Bootstrap's hidden.bs.modal event can call it via element.addEventListener
  // (wired in connect()). Do not use data-action for this — it's already bound there.
  onDismiss = () => {
    this.#resolve?.(null)
    this.#resolve = null
  }
}
