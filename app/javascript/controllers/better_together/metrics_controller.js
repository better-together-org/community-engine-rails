// app/javascript/controllers/metrics_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.handleClickBound = this.handleClick.bind(this)
    this.trackPageViewBound = this.trackPageView.bind(this)

    this.element.addEventListener("click", this.handleClickBound)

    this.linkMetricsUrl = this.element.dataset.linkMetricsUrl
    this.pageViewUrl = this.element.dataset.pageViewUrl
    this.viewableType = this.element.dataset.viewableType
    this.viewableId = this.element.dataset.viewableId
    this.pageViewTracked = false

    document.addEventListener("DOMContentLoaded", this.trackPageViewBound)
    document.addEventListener("turbo:load", this.trackPageViewBound)
  }

  disconnect() {
    this.element.removeEventListener("click", this.handleClickBound)
    document.removeEventListener("DOMContentLoaded", this.trackPageViewBound)
    document.removeEventListener("turbo:load", this.trackPageViewBound)
  }

  trackPageView() {
    if (this.pageViewTracked || !this.pageViewUrl || !this.viewableType || !this.viewableId) return
    this.pageViewTracked = true
    fetch(this.pageViewUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({
        viewable_type: this.viewableType,
        viewable_id: this.viewableId,
        locale: document.documentElement.lang
      })
    }).catch(error => {
      console.error("Error tracking page view:", error)
    })
  }

  handleClick(event) {
    const excludedClasses = '.profiler-results a, trix-editor a'
    const link = event.target.closest(`a:not(${excludedClasses})`)
    if (!link) return

    const url = link.href
    const isInternal = this.isInternalLink(url)
    const currentPageUrl = window.location.href

    if (!isInternal) {
      window.open(url, "_blank")
      event.preventDefault()
    }

    this.trackLinkClick(url, currentPageUrl, isInternal)
  }

  trackLinkClick(clickedUrl, pageUrl, internal) {
    if (!this.linkMetricsUrl) return
    fetch(this.linkMetricsUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({
        url: clickedUrl,
        page_url: pageUrl,
        internal: internal
      })
    }).then(response => {
      if (!response.ok) {
        console.error("Failed to track link click")
      }
    }).catch(error => {
      console.error("Error tracking link click:", error)
    })
  }

  isInternalLink(url) {
    try {
      const linkUrl = new URL(url)
      return linkUrl.host === window.location.host
    } catch (e) {
      console.error("Error parsing URL:", e)
      return false
    }
  }

  getCSRFToken() {
    const tokenElement = document.querySelector("meta[name='csrf-token']")
    return tokenElement ? tokenElement.getAttribute("content") : ""
  }
}
