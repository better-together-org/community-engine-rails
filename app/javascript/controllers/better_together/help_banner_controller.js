import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { id: String, locale: String, hideUrl: String }

  connect() {
    const key = this.#key()
    try {
      const state = window.localStorage.getItem(key)
      if (state === 'hidden') this.#hideElement()
    } catch (_) {
      // localStorage may be unavailable; ignore
    }
  }

  hide(event) {
    if (event) event.preventDefault()
    this.#persistServer()
    this.#hideElement()
  }

  #hideElement() {
    this.element.style.display = 'none'
  }

  #key() {
    const id = this.hasIdValue ? this.idValue : (this.element.dataset.helpBannerId || 'help')
    const locale = this.hasLocaleValue ? this.localeValue : (document.documentElement.getAttribute('lang') || '')
    return `bt_help_banner_${id}_${locale}`
  }

  #persistServer() {
    const url = this.hasHideUrlValue ? this.hideUrlValue : (this.element.dataset.helpBannerHideUrl || '')
    const id = this.hasIdValue ? this.idValue : (this.element.dataset.helpBannerId || 'help')
    console.log('HelpBannerController: Using hide URL:', url) // Debug log
    if (!url) {
      console.error('HelpBannerController: Missing hide URL')
      return
    }
    try {
      fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.#csrfToken() },
        body: JSON.stringify({ id })
      }).then(response => {
        if (!response.ok) {
          console.error('HelpBannerController: Failed to persist hide state on server', response)
        }
      }).catch(error => {
        console.error('HelpBannerController: Network error while persisting hide state', error)
      })
    } catch (error) {
      console.error('HelpBannerController: Unexpected error while persisting hide state', error)
    }
  }

  #csrfToken() {
    const meta = document.querySelector('meta[name="csrf-token"]')
    return meta && meta.getAttribute('content')
  }
}
