import { Controller } from '@hotwired/stimulus'

// Handles same-document anchor navigation inside a Turbo Frame that is used
// inside a modal (agreement modal). Prevents Turbo frame reloads for
// fragment-only links and same-path+fragment links by scrolling to the target
// element within the frame instead.
export default class extends Controller {
  connect () {
    this.onFrameLoad = this.onFrameLoad.bind(this)
    document.addEventListener('turbo:frame-load', this.onFrameLoad)

    this.onClick = this.onClick.bind(this)
    this.element.addEventListener('click', this.onClick)
  }

  disconnect () {
    document.removeEventListener('turbo:frame-load', this.onFrameLoad)
    this.element.removeEventListener('click', this.onClick)
  }

  onFrameLoad (event) {
    if (event.target !== this.element) return
    // If the URL already has a hash, try to scroll to it within the frame
    try {
      const hash = window.location.hash
      if (hash) this.scrollToHash(hash)
    } catch (e) {
      // ignore
    }
  }

  onClick (e) {
    const anchor = e.target.closest('a')
    if (!anchor) return

    const href = anchor.getAttribute('href')
    if (!href) return

    // Fragment-only links (#id)
    if (href.charAt(0) === '#') {
      const target = this.element.querySelector(href)
      if (target) {
        e.preventDefault()
        this.scrollToElement(target)
        try { history.replaceState(history.state, document.title, href) } catch (err) {}
      }
      return
    }

    // Links that point to same path + fragment (e.g. /path#id)
    try {
      const linkUrl = new URL(href, window.location.href)
      const frameSrc = this.element.getAttribute('src') || window.location.href
      const frameUrl = new URL(frameSrc, window.location.href)

      if (linkUrl.origin === window.location.origin && linkUrl.pathname === frameUrl.pathname && linkUrl.hash) {
        const target = this.element.querySelector(linkUrl.hash)
        if (target) {
          e.preventDefault()
          this.scrollToElement(target)
          try { history.replaceState(history.state, document.title, linkUrl.hash) } catch (err) {}
        }
      }
    } catch (err) {
      // ignore URL parsing errors and allow default navigation
    }
  }

  scrollToElement (element) {
    // Attempt to scroll the nearest scrollable container containing the element
    // (modal body) so the target is visible to users.
    // Find closest ancestor with overflow auto/scroll; fallback to element.scrollIntoView

    let scrollContainer = element.closest('.modal-body') || this.element
    try {
      element.scrollIntoView({ behavior: 'smooth', block: 'start' })
      element.focus({ preventScroll: true })
    } catch (err) {
      // fallback
      element.scrollIntoView()
    }
  }

  scrollToHash (hash) {
    try {
      const target = this.element.querySelector(hash)
      if (target) this.scrollToElement(target)
    } catch (err) {}
  }
}
