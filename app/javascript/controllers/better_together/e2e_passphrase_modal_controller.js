import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message", "input"]

  #resolve = null
  #modal   = null

  connect() {
    document.addEventListener('e2e:request-passphrase', this.#onRequest)
    document.addEventListener('e2e:request-confirm',    this.#onRequest)
    this.#modal = new window.bootstrap.Modal(this.element)
    this.element.addEventListener('hidden.bs.modal', this.#onDismiss)
  }

  disconnect() {
    document.removeEventListener('e2e:request-passphrase', this.#onRequest)
    document.removeEventListener('e2e:request-confirm',    this.#onRequest)
  }

  submit() {
    const value = this.hasInputTarget ? this.inputTarget.value.trim() : true
    this.#resolve?.(value || null)
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
    this.messageTarget.textContent = message
    if (this.hasInputTarget) {
      this.inputTarget.value = ''
      this.inputTarget.style.display = showInput ? '' : 'none'
      this.inputTarget.minLength = minLength ?? 0
    }
    this.#resolve = resolve
    this.#modal.show()
  }

  #onDismiss = () => {
    this.#resolve?.(null)
    this.#resolve = null
  }
}
