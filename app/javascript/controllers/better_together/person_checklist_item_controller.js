import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = { checklistId: String, checklistItemId: String }
  static targets = [ 'checkbox', 'timestamp', 'container' ]

  // Safe accessors for optional globals used in templates.
  get locale() {
    try {
      if (typeof I18n !== 'undefined' && I18n && I18n.locale) return I18n.locale
    } catch (e) {}
    // Fallback to html lang attribute or default 'en'
    try {
      const htmlLang = document.documentElement.getAttribute('lang')
      if (htmlLang) return htmlLang
    } catch (e) {}
    return 'en'
  }

  get routeScopePath() {
    try {
      if (typeof BetterTogether !== 'undefined' && BetterTogether && BetterTogether.route_scope_path) return BetterTogether.route_scope_path
    } catch (e) {}
    // If not present, try a data attribute on the element
    try {
      if (this.element && this.element.dataset && this.element.dataset.routeScopePath) return this.element.dataset.routeScopePath
    } catch (e) {}
    return ''
  }

  connect() {
  // If server indicated no person is present, do not initialize this controller
  try {
    const canToggle = this.element.dataset.personToggle !== 'false'
    if (!canToggle) return
  } catch (e) {}

  // Read CSRF token from meta tag or cookie (robust fallback)
  this.csrf = this.getCSRFToken()
  this.fetchPersonRecord()
  // Fallback: ensure toggle still works when data-action is missing by
  // attaching event listeners directly to the checkbox target.
  try {
    if (this.hasCheckboxTarget) {
      this._boundToggle = (e) => {
        if (e.type === 'keydown' && !(e.key === 'Enter' || e.key === ' ')) return
        e.preventDefault()
        this.toggle(e)
      }
      this.checkboxTarget.addEventListener('click', this._boundToggle)
      this.checkboxTarget.addEventListener('keydown', this._boundToggle)
    }
  } catch (e) {}
  }

  disconnect() {
    try {
      if (this._boundToggle && this.hasCheckboxTarget) {
        this.checkboxTarget.removeEventListener('click', this._boundToggle)
        this.checkboxTarget.removeEventListener('keydown', this._boundToggle)
      }
    } catch (e) {}
  }

  fetchPersonRecord() {
  const url = `/${this.locale}/${this.routeScopePath}/checklists/${this.checklistIdValue}/checklist_items/${this.checklistItemIdValue}/person_checklist_item`
    fetch(url, { credentials: 'same-origin', headers: { 'Accept': 'application/json', 'X-Requested-With': 'XMLHttpRequest' } })
      .then((r) => {
        if (!r.ok) {
          console.error('person_checklist_item: failed to fetch person record', r.status)
          return null
        }
        return r.json()
      })
      .then((data) => {
        if (data) {
          // update UI with fetched state
          this.updateUI(data)
        }
      }).catch((err) => { console.error('person_checklist_item: fetchPersonRecord error', err) })
  }

  updateUI(data) {
    if (!this.hasCheckboxTarget) return

    const done = !!data.completed_at
    this.checkboxTarget.classList.toggle('completed', done)
    this.checkboxTarget.setAttribute('aria-pressed', done)

    // Toggle timestamp display
    if (this.hasTimestampTarget) {
      this.timestampTarget.textContent = done ? new Date(data.completed_at).toLocaleString() : ''
    }

    // Toggle Font Awesome check visibility.
    // Preferred pattern: toggle visibility on an existing checkmark icon (fa-check or similar).
    const checkmarkEl = this.checkboxTarget.querySelector('.fa-check, .fa-check-square, .fa-check-circle')
    if (checkmarkEl) {
      checkmarkEl.classList.toggle('d-none', !done)
    }
  }

  async toggle(event) {
    event.preventDefault()
    const currentlyDone = this.checkboxTarget.classList.contains('completed')
  const url = `/${this.locale}/${this.routeScopePath}/checklists/${this.checklistIdValue}/checklist_items/${this.checklistItemIdValue}/person_checklist_item`
    const payload = JSON.stringify({ completed: !currentlyDone })

    const maxAttempts = 3
    let attempt = 0
    let lastError = null

    while (attempt < maxAttempts) {
      try {
        attempt += 1
        const r = await fetch(url, {
          method: 'POST',
          credentials: 'same-origin',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-CSRF-Token': this.getCSRFToken(),
            'X-Requested-With': 'XMLHttpRequest'
          },
          body: payload
        })

        if (!r.ok) {
          // Attempt to get JSON error details if present
          let errBody = null
          try { errBody = await r.json() } catch (e) { /* ignore */ }
          lastError = { status: r.status, body: errBody }

          // Show server-provided flash if present
          try {
            if (errBody && errBody.flash && window.BetterTogetherNotifications && typeof window.BetterTogetherNotifications.displayFlashMessage === 'function') {
              window.BetterTogetherNotifications.displayFlashMessage(errBody.flash.type || 'alert', errBody.flash.message || errBody.errors?.join(', ') || 'An error occurred')
            }
          } catch (e) { /* noop */ }

          // Retry on server errors (5xx). For 4xx, break early.
          if (r.status >= 500) {
            const backoff = 200 * attempt
            await new Promise((res) => setTimeout(res, backoff))
            continue
          } else {
            break
          }
        }

  const data = await r.json()
      // update UI with returned state
  this.updateUI(data)
  // Show server-provided flash if present
  try {
    if (data && data.flash && window.BetterTogetherNotifications && typeof window.BetterTogetherNotifications.displayFlashMessage === 'function') {
      window.BetterTogetherNotifications.displayFlashMessage(data.flash.type || 'notice', data.flash.message || '')
    }
  } catch (e) { /* noop */ }
  // Dispatch an event for checklist-level listeners with detail
  this.element.dispatchEvent(new CustomEvent('person-checklist-item:toggled', { bubbles: true, detail: { checklist_item_id: this.checklistItemIdValue, status: 'toggled', data } }))
        return
      } catch (err) {
        console.error(`person_checklist_item: POST error (attempt ${attempt})`, err)
        lastError = err
        const backoff = 200 * attempt
        await new Promise((res) => setTimeout(res, backoff))
      }
    }

    // If we reach here, all attempts failed. Optionally show a visual error.
    console.error('person_checklist_item: all attempts failed')
    // Basic user feedback: toggle an error class briefly
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add('person-checklist-error')
      setTimeout(() => this.containerTarget.classList.remove('person-checklist-error'), 3000)
    }
    // Show a fallback flash message for persistent failures
    try {
      const msg = (typeof I18n !== 'undefined' && I18n && I18n.t) ? I18n.t('flash.checklist_item.update_failed') : 'Failed to update checklist item.'
      if (window.BetterTogetherNotifications && typeof window.BetterTogetherNotifications.displayFlashMessage === 'function') {
        window.BetterTogetherNotifications.displayFlashMessage('alert', msg)
      }
    } catch (e) { /* noop */ }
  }

  getCSRFToken() {
    const meta = document.querySelector("meta[name='csrf-token']")
    if (meta && meta.content) return meta.content

    // Fallback: parse document.cookie for CSRF token name used by Rails
    const match = document.cookie.match(/(?:^|; )csrf-token=([^;]+)/)
    if (match) return decodeURIComponent(match[1])
    return ''
  }
}
