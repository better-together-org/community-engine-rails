import { Controller } from "@hotwired/stimulus";

// filepath: app/javascript/controllers/better_together/tabs_controller.js

export default class extends Controller {
  static targets = ["tab"];

  connect() {
    // Get all available tabs (both via Stimulus targets and manual selection)
    this.allTabs = this.tabTargets.length > 0 ? this.tabTargets : 
                   Array.from(this.element.querySelectorAll('[data-bs-toggle="tab"]'));
    
    this.activateTabFromHash();
    this.setupTabChangeListener();
  }

  activateTabFromHash() {
    const hash = window.location.hash;
    if (hash) {
      // Look for tabs that target this hash with either href or data-bs-target
      let selectedTab = this.element.querySelector(`[href="${hash}"]`) || 
                       this.element.querySelector(`[data-bs-target="${hash}"]`);
      
      if (selectedTab && !selectedTab.closest('.localized-fields')) {
        console.log('Activating tab from hash:', hash, selectedTab);
        
        // Let Bootstrap handle the tab activation
        const tabInstance = new bootstrap.Tab(selectedTab);
        tabInstance.show();
      }
    }
  }

  setupTabChangeListener() {
    // Use the unified collection of all available tabs
    const tabsToSetup = this.allTabs || [];
    
    tabsToSetup.forEach((link) => {
      if (link.closest('.localized-fields')) return;

      // Primary: Listen for click events
      link.addEventListener("click", (event) => {
        const targetHash = event.target.getAttribute("href") || event.target.getAttribute("data-bs-target");
        
        if (targetHash && targetHash.startsWith('#')) {
          // Update immediately - no delay needed
          history.pushState({}, "", targetHash);
        }
      });
    });
  }
}