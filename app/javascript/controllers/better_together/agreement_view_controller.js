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

    // handle modal hidden events so we can reset notice state when the user
    // opened and closed without scrolling
    this._onModalHidden = this._onModalHidden.bind(this)
    this._modalEl = document.getElementById('agreementModal')
    if (this._modalEl) this._modalEl.addEventListener('hidden.bs.modal', this._onModalHidden)

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

    // remove modal listener
    if (this._modalEl) this._modalEl.removeEventListener('hidden.bs.modal', this._onModalHidden)
  }

  // Called when the agreement modal is hidden; if the user didn't actually
  // scroll the content during the modal session, clear the shown-notice flag
  // so the notice will be available again next time they attempt to accept.
  _onModalHidden (event) {
    const agreementId = this.element.dataset.agreementIdentifier || this.element.getAttribute('data-agreement-identifier')
    if (!agreementId) return

    // if the user never scrolled during the modal session, allow the notice
    // to be shown again on the next attempt
    if (!this._userScrolled) {
      delete this._noticeShownFor[agreementId]
    }

    // reset scroll state
    this._userScrolled = false
  }

  onFrameLoad (event) {
    const frame = event.target
    if (!frame || frame !== this.element) return

    // Wait for content to render inside the frame
    const frameDocument = this.element.contentDocument || this.element.querySelector('iframe')?.contentDocument

    // Turbo frame is inside the modal; use the modal's scrollable body as
    // the scroll container so we observe the real scrolling element.
    // Prefer closest('.modal-body') (ancestor) rather than searching inside the frame.
    this.frameBody = this.element.closest('.modal-body') || this.element

    // Reset scroll state for this frame load: require the user to actually
    // perform a scroll interaction before we enable the checkbox (unless the
    // content doesn't scroll at all, see checkScrollPosition).
    this._userScrolled = false

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
      // Also check immediately in case content is small or already at bottom,
      // but do NOT enable the checkbox unless the user has scrolled (handled
      // inside checkScrollPosition). Short content is treated as already-read.
      this.checkScrollPosition()
    }
  }

  onScroll () {
    // mark that the user interacted by scrolling
    this._userScrolled = true

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

  checkScrollPosition () {
    if (!this.frameBody) return

    const scrollTop = this.frameBody.scrollTop
    const scrollHeight = this.frameBody.scrollHeight
    const clientHeight = this.frameBody.clientHeight

    // Determine whether the content actually requires scrolling
    const contentScrollable = scrollHeight > clientHeight

    // Consider the user has reached bottom when within 48px of the end
    const atBottom = (scrollTop + clientHeight) >= (scrollHeight - 48)

    const agreementId = this.element.dataset.agreementIdentifier || this.element.getAttribute('data-agreement-identifier')
    if (!agreementId) return

    const checkbox = document.querySelector(`${this.checkboxSelectorValue}[data-agreement-identifier="${agreementId}"]`)
    if (!checkbox) return

    // If the content doesn't scroll, treat it as already read and allow
    // immediate enabling. Otherwise require that the user actually scrolled
    // and reached the bottom.
    const userHasSeen = !contentScrollable || this._userScrolled

    if (atBottom && userHasSeen) {
      // Enable the checkbox and ensure it is NOT readonly so form validators
      // don't treat it as a read-only (and therefore already-valid) input.
      checkbox.disabled = false
      try {
        checkbox.readOnly = false
      } catch (e) {
        // noop
      }
      checkbox.removeAttribute('readonly')
      checkbox.setAttribute('aria-disabled', 'false')
      checkbox.dataset.betterTogetherAgreementEnabled = 'true'

      // Optionally focus the checkbox to signal it's now actionable
      checkbox.focus()
    }
  }

  showNotice (agreementId) {
    // show the notice modal once per agreement per page load
    if (agreementId && this._noticeShownFor[agreementId]) return
    if (agreementId) this._noticeShownFor[agreementId] = true

    const modalEl = document.getElementById('agreementNoticeModal')

    // If the agreement modal is already open, show an inline alert inside it
    const outerAgreementModal = document.getElementById('agreementModal')
    if (outerAgreementModal && outerAgreementModal.classList && outerAgreementModal.classList.contains('show')) {
      const modalBody = outerAgreementModal.querySelector('.modal-body')
      if (modalBody) {
        // remove existing temporary notice if any
        const existing = modalBody.querySelector('.bt-agreement-inline-notice')
        if (existing) existing.remove()

        const notice = document.createElement('div')
        notice.className = 'alert alert-info bt-agreement-inline-notice'
        notice.setAttribute('role', 'alert')
        notice.setAttribute('aria-live', 'polite')
        notice.textContent = 'Please view the full agreement before accepting.'

        // insert at the top of the modal body
        modalBody.prepend(notice)

        // remove after a short timeout
        setTimeout(() => { notice.remove() }, 5000)
        return
      }
    }

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
      try { alert('Please view the full agreement before accepting.') } catch (e) { /* noop */ }
    }
  }
}
