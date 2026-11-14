import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['modal', 'frame', 'acceptButton', 'cancelButton']
  static values = {
    closeLabel: String,
    cancelLabel: String,
    acceptLabel: String,
    acceptedLabel: String,
    acceptingLabel: String,
    acceptError: String
  }

  connect () {
    this.onModalHidden = this.onModalHidden.bind(this)
    this.modalElement.addEventListener('hidden.bs.modal', this.onModalHidden)
    this.resetState()
  }

  disconnect () {
    this.modalElement.removeEventListener('hidden.bs.modal', this.onModalHidden)
  }

  open (event) {
    const link = event.target.closest && event.target.closest('.agreement-modal-link')
    if (!link) return

    event.preventDefault()

    this.currentAgreementIdentifier = link.dataset.agreementIdentifier || ''
    this.currentMode = link.dataset.agreementMode || 'checkbox_unlock'
    this.currentAcceptUrl = link.dataset.agreementAcceptUrl || ''

    this.frameTarget.dataset.agreementIdentifier = this.currentAgreementIdentifier
    this.frameTarget.dataset.agreementMode = this.currentMode
    this.frameTarget.setAttribute('src', link.getAttribute('href'))

    this.configureFooter()
    bootstrap.Modal.getOrCreateInstance(this.modalElement).show()
  }

  handleReviewComplete (event) {
    if (this.currentMode !== 'direct_accept') return
    if (event.detail?.agreementIdentifier !== this.currentAgreementIdentifier) return

    this.acceptButtonTarget.disabled = false
  }

  async accept (event) {
    event.preventDefault()
    if (this.currentMode !== 'direct_accept') return
    if (!this.currentAcceptUrl || this.acceptButtonTarget.disabled) return

    const originalLabel = this.acceptButtonTarget.textContent
    this.acceptButtonTarget.disabled = true
    this.acceptButtonTarget.textContent = this.acceptingLabelValue || originalLabel

    try {
      const response = await fetch(this.currentAcceptUrl, {
        method: 'POST',
        headers: {
          Accept: 'application/json',
          'X-CSRF-Token': this.csrfToken,
          'X-Requested-With': 'XMLHttpRequest'
        },
        credentials: 'same-origin'
      })

      const payload = await response.json().catch(() => ({}))
      if (!response.ok) throw new Error(payload.error || this.acceptErrorValue)

      this.markAgreementAccepted(payload.agreement_identifier || this.currentAgreementIdentifier)
      document.dispatchEvent(new CustomEvent('better_together:agreement-accepted', {
        detail: payload,
        bubbles: true
      }))

      this.acceptButtonTarget.textContent = this.acceptedLabelValue || originalLabel
      bootstrap.Modal.getOrCreateInstance(this.modalElement).hide()
    } catch (error) {
      this.acceptButtonTarget.disabled = false
      this.acceptButtonTarget.textContent = originalLabel
      this.showInlineError(error.message || this.acceptErrorValue)
    }
  }

  get modalElement () {
    return this.modalTarget
  }

  get csrfToken () {
    return document.querySelector('meta[name="csrf-token"]')?.content || ''
  }

  configureFooter () {
    this.clearInlineError()
    this.acceptButtonTarget.textContent = this.acceptLabelValue || 'I agree'

    if (this.currentMode === 'direct_accept') {
      this.cancelButtonTarget.textContent = this.cancelLabelValue || 'Cancel'
      this.acceptButtonTarget.classList.remove('d-none')
      this.acceptButtonTarget.disabled = true
    } else {
      this.cancelButtonTarget.textContent = this.closeLabelValue || 'Close'
      this.acceptButtonTarget.classList.add('d-none')
      this.acceptButtonTarget.disabled = true
    }
  }

  onModalHidden () {
    const frame = this.frameTarget
    frame.removeAttribute('src')
    frame.removeAttribute('data-agreement-identifier')
    frame.dataset.agreementMode = 'checkbox_unlock'
    this.resetState()

    if (window?.location?.hash) {
      try {
        const newUrl = window.location.pathname + window.location.search
        history.replaceState(null, document.title, newUrl)
      } catch (error) {
        // no-op
      }
    }
  }

  resetState () {
    this.currentAgreementIdentifier = null
    this.currentMode = 'checkbox_unlock'
    this.currentAcceptUrl = null
    this.configureFooter()
  }

  markAgreementAccepted (agreementIdentifier) {
    if (!agreementIdentifier) return

    document.querySelectorAll(`[data-agreement-identifier="${agreementIdentifier}"]`).forEach((element) => {
      if (element.matches('input[type="checkbox"].agreement-checkbox')) {
        element.dataset.betterTogetherAgreementEnabled = 'true'
        element.disabled = false
        element.checked = true
      }

      if (element.classList.contains('agreement-modal-link') && element.dataset.agreementMode === 'direct_accept') {
        element.classList.remove('btn-outline-danger')
        element.classList.add('btn-outline-success')
        element.textContent = this.acceptedLabelValue || 'Accepted'
        element.dataset.agreementAccepted = 'true'
      }
    })
  }

  showInlineError (message) {
    this.clearInlineError()

    const notice = document.createElement('div')
    notice.className = 'alert alert-danger w-100 me-auto mb-0'
    notice.setAttribute('role', 'alert')
    notice.dataset.agreementModalError = 'true'
    notice.textContent = message

    this.modalElement.querySelector('.modal-footer').prepend(notice)
  }

  clearInlineError () {
    this.modalElement.querySelector('[data-agreement-modal-error="true"]')?.remove()
  }
}
