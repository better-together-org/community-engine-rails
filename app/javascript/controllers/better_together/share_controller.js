// app/javascript/controllers/share_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  share(event) {
    event.preventDefault()
    const platform = event.currentTarget.dataset.platform
    const url = event.currentTarget.dataset.url
    const title = event.currentTarget.dataset.title || document.title
    const image = event.currentTarget.dataset.image || ""
    const shareTrackingUrl = event.currentTarget.dataset.shareTrackingUrl
    const shareableType = event.currentTarget.dataset.shareableType
    const shareableId = event.currentTarget.dataset.shareableId

    const shareUrl = this.constructShareUrl(platform, url, title, image)
    if (!shareUrl) return

    // Open the share window
    window.open(shareUrl, '_blank', 'width=600,height=400')

    // Track the share internally via AJAX
    this.trackShare(platform, url, shareTrackingUrl, shareableType, shareableId)

    // Conditionally trigger Google Analytics event
    if (window.GA_ID) {
      this.trackWithGA(platform, url, title)
    }
  }

  constructShareUrl(platform, url, title, image) {
    const encodedUrl = encodeURIComponent(url)
    const encodedTitle = encodeURIComponent(title)
    const encodedImage = encodeURIComponent(image)

    switch (platform) {
      case 'facebook':
        return `https://www.facebook.com/sharer/sharer.php?u=${encodedUrl}`;
      case 'twitter':
        return `https://twitter.com/intent/tweet?url=${encodedUrl}&text=${encodedTitle}`;        
      case 'linkedin':
        return `https://www.linkedin.com/sharing/share-offsite/?url=${encodedUrl}`;
      case 'pinterest':
        return `https://pinterest.com/pin/create/button/?url=${encodedUrl}&media=${encodedImage}&description=${encodedTitle}`;
      case 'reddit':
        return `https://www.reddit.com/submit?url=${encodedUrl}&title=${encodedTitle}`;
      case 'whatsapp':
        return `https://api.whatsapp.com/send?text=${encodedTitle}%20${encodedUrl}`;        
      default:
        console.warn(this.localizedString('share_controller.unsupported_platform', { platform: platform }))
        return null
    }
  }

  trackShare(platform, url, shareTrackingUrl, shareableType, shareableId) {
    const payload = { platform, url }
    if (shareableType && shareableId) {
      payload.shareable_type = shareableType
      payload.shareable_id = shareableId
    }

    fetch(shareTrackingUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify(payload)
    })
    .then(response => {
      if (!response.ok) {
        console.error(this.localizedString('share_controller.failed_tracking'))
      }
    })
    .catch(error => {
      console.error(this.localizedString('share_controller.error_tracking'), error)
    })
  }

  trackWithGA(platform, url, title) {
    if (typeof gtag === 'function') {
      gtag('event', 'share', {
        'method': platform,
        'content_type': 'article',
        'item_id': url,
        'item_title': title
      })
    } else if (typeof ga === 'function') {
      ga('send', 'event', 'Social Share', platform, title)
    } else {
      console.warn(this.localizedString('share_controller.ga_not_initialized'))
    }
  }

  getCSRFToken() {
    const tokenElement = document.querySelector("meta[name='csrf-token']")
    return tokenElement ? tokenElement.getAttribute("content") : ""
  }

  localizedString(key, options = {}) {
    // Fetch translated strings from a JSON endpoint or embed translations
    // For simplicity, assume translations are embedded in a global JS object
    return window.I18n && window.I18n.t ? window.I18n.t(key, options) : key
  }
}
