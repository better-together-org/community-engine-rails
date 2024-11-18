// app/javascript/controllers/link_click_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Attach event listener to all links on the page
    this.element.addEventListener("click", this.handleClick.bind(this))

    // Get the localized link_click_path from the data attribute
    this.linkMetricsUrl = this.element.dataset.linkMetricsUrl;
  }

  disconnect() {
    // Remove event listener when the controller disconnects
    this.element.removeEventListener("click", this.handleClick.bind(this))
  }

  handleClick(event) {
    const excludedClasses = '.profiler-queries-show';
    // Check if the target is an anchor tag or if it has an anchor tag parent
    const link = event.target.closest(`a:not(${excludedClasses})`);
    if (!link) return;

    const url = link.href;
    const isInternal = this.isInternalLink(url);
    const currentPageUrl = window.location.href;

    if (!isInternal) {
      // Open the external link in a new tab
      window.open(url, "_blank");
      // Prevent the default link click behavior in the current tab
      event.preventDefault();
    }

    // Track the link click in the original tab
    this.trackLinkClick(url, currentPageUrl, isInternal);
  }

  trackLinkClick(clickedUrl, pageUrl, internal) {
    // Use the localized link_click_path from the data attribute
    fetch(this.linkMetricsUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": this.getCSRFToken()
      },
      body: JSON.stringify({
        url: clickedUrl,  // The clicked link's URL
        page_url: pageUrl,  // The current page URL
        internal: internal  // Whether the link is internal or external
      })
    }).then(response => {
      if (!response.ok) {
        console.error("Failed to track link click");
      }
    }).catch(error => {
      console.error("Error tracking link click:", error);
    });
  }

  isInternalLink(url) {
    try {
      const linkUrl = new URL(url);
      return linkUrl.host === window.location.host;
    } catch (e) {
      console.error("Error parsing URL:", e);
      return false;
    }
  }

  getCSRFToken() {
    const tokenElement = document.querySelector("meta[name='csrf-token']");
    return tokenElement ? tokenElement.getAttribute("content") : "";
  }
}
