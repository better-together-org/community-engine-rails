import { Controller } from '@hotwired/stimulus'

// Controls the modal turbo-frame and enables the corresponding checkbox when
// the user has scrolled to the bottom of the agreement content.
export default class extends Controller {
  static values = {
    // Selector for agreement checkboxes
    checkboxSelector: { type: String, default: '.agreement-checkbox' }
  }

  connect () {
    this.onFrameLoad = this.onFrameLoad.bind(this)
    this.onScroll = this.onScroll.bind(this)

    // debounce handle for the scroll event
    this._scrollDebounce = null

    // handlers to block interaction with agreement checkboxes until enabled
    this._preventToggleClick = this._preventToggleClick.bind(this)
    this._preventToggleKeydown = this._preventToggleKeydown.bind(this)

    // capture-phase listeners so we can stop the action before other handlers
    document.addEventListener('click', this._preventToggleClick, true)
    document.addEventListener('keydown', this._preventToggleKeydown, true)

    // keep track of which agreement notices we've shown this session
    this._noticeShownFor = {}

    document.addEventListener('turbo:frame-load', this.onFrameLoad)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-load', this.onFrameLoad)
    if (this.frameBody) this.frameBody.removeEventListener('scroll', this.onScroll)

    // clear any pending debounce timer
    if (this._scrollDebounce) {
      clearTimeout(this._scrollDebounce)
      this._scrollDebounce = null
    }

    // remove global handlers
    document.removeEventListener('click', this._preventToggleClick, true)
    document.removeEventListener('keydown', this._preventToggleKeydown, true)
  }

  onFrameLoad (event) {
    const frame = event.target
    if (!frame || frame !== this.element) return

    // Wait for content to render inside the frame
    const frameDocument = this.element.contentDocument || this.element.querySelector('iframe')?.contentDocument

    // Turbo frame content is in the DOM under the frame element; we can query
    // within the frame element for the modal-body or main container.
    this.frameBody = this.element.querySelector('.modal-body') || this.element

    if (this.frameBody) {
      // Ensure the frame starts scrolled at the top
      try {
        // small timeout to allow content layout (images, fonts)
        setTimeout(() => {
          if (this.frameBody.scrollTo) {
            this.frameBody.scrollTo({ top: 0, behavior: 'auto' })
          } else {
            this.frameBody.scrollTop = 0
          }
        }, 10)
      } catch (e) {
        // noop
      }

      // attach debounced scroll handler
      this.frameBody.addEventListener('scroll', this.onScroll)
      // Also check immediately in case content is small
      this.checkScrollPosition()
    }
  }

  onScroll () {
    // debounce scroll events to avoid noisy validation checks
    if (this._scrollDebounce) clearTimeout(this._scrollDebounce)
    this._scrollDebounce = setTimeout(() => { this.checkScrollPosition() }, 150)
  }

  // Prevent clicks on locked agreement checkboxes
  _preventToggleClick (event) {
    const target = event.target.closest && event.target.closest('input[type="checkbox"].agreement-checkbox')
    if (!target) return

    // if the checkbox has been enabled by the controller, allow interaction
    if (target.dataset && target.dataset.betterTogetherAgreementEnabled === 'true') return

    // otherwise prevent the toggle and show the notice
    event.preventDefault()
    event.stopPropagation()

    const agreementId = target.dataset && target.dataset.agreementIdentifier
    this.showNotice(agreementId)
  }

  // Prevent keyboard toggles (Space/Enter) when checkbox is locked
  _preventToggleKeydown (event) {
    const active = document.activeElement
    if (!active) return
    if (!active.matches || !active.matches('input[type="checkbox"].agreement-checkbox')) return

    if (active.dataset && active.dataset.betterTogetherAgreementEnabled === 'true') return

    // Space toggles checkbox; Enter may also activate depending on markup
    if (event.code === 'Space' || event.key === ' ' || event.key === 'Spacebar' || event.key === 'Enter') {
      event.preventDefault()
      event.stopPropagation()

      const agreementId = active.dataset && active.dataset.agreementIdentifier
      this.showNotice(agreementId)
    }
  }

  showNotice (agreementId) {
    // show the notice modal once per agreement per page load
    if (agreementId && this._noticeShownFor[agreementId]) return
    if (agreementId) this._noticeShownFor[agreementId] = true

    const modalEl = document.getElementById('agreementNoticeModal')
    if (!modalEl) {
      // fallback to a simple alert if modal markup isn't present
      try {
        alert('Please view the full agreement before accepting.')
      } catch (e) {
        // noop
      }
      return
    }

    try {
      const bsModal = bootstrap.Modal.getOrCreateInstance(modalEl)
      bsModal.show()
      // focus the close button for accessibility
      const closeBtn = modalEl.querySelector('[data-bs-dismiss="modal"]')
      if (closeBtn) closeBtn.focus()
    } catch (e) {
      // fallback
      try { alert('Please view the full agreement before accepting.') } catch (e) { /* noop */ }
    }
  }

  checkScrollPosition () {
    if (!this.frameBody) return

    const scrollTop = this.frameBody.scrollTop
    const scrollHeight = this.frameBody.scrollHeight
    const clientHeight = this.frameBody.clientHeight

    // Consider the user has reached bottom when within 48px of the end
    const atBottom = (scrollTop + clientHeight) >= (scrollHeight - 48)

    const agreementId = this.element.dataset.agreementIdentifier || this.element.getAttribute('data-agreement-identifier')
    if (!agreementId) return

    const checkbox = document.querySelector(`${this.checkboxSelectorValue}[data-agreement-identifier="${agreementId}"]`)
    if (!checkbox) return

    if (atBottom) {
      // Enable the checkbox and ensure it is NOT readonly so form validators
      // don't treat it as a read-only (and therefore already-valid) input.
      checkbox.disabled = false
      try {
        // some browsers may not allow toggling readOnly on checkboxes but
        // remove any readonly state if present.
        checkbox.readOnly = false
      } catch (e) {
        // noop
      }
      checkbox.removeAttribute('readonly')
      checkbox.setAttribute('aria-disabled', 'false')
      // mark as enabled so other scripts can detect state
      checkbox.dataset.betterTogetherAgreementEnabled = 'true'

      // Optionally focus the checkbox to signal it's now actionable
      checkbox.focus()
    }
  }
}
