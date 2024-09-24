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
    // Check if the target is an anchor tag or if it has an anchor tag parent
    const link = event.target.closest("a");
    if (!link) return;

    // Prevent the default action only if it's a valid link
    if (link.href && link.href != '#') {
      const url = link.href;
      const isInternal = this.isInternalLink(url);
      const currentPageUrl = window.location.href; // Get the current page URL

      // Dispatch the request to track the link click
      this.trackLinkClick(url, currentPageUrl, isInternal);
    }
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
    const host = window.location.host;
    return url.includes(host); // Check if the URL includes the current host
  }

  getCSRFToken() {
    const tokenElement = document.querySelector("meta[name='csrf-token']");
    return tokenElement ? tokenElement.getAttribute("content") : "";
  }
}
