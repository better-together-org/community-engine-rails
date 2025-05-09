import { Controller } from "@hotwired/stimulus";
import * as bootstrap from "bootstrap";

// filepath: app/javascript/controllers/better_together/tabs_controller.js

export default class extends Controller {
  static targets = ["tab"];

  connect() {
    this.activateTabFromHash();
    this.setupTabChangeListener();
  }

  activateTabFromHash() {
    const hash = window.location.hash;
    if (hash) {
      let selectedTab = this.element.querySelector(`[data-bs-target="${hash}"]`);
      while (selectedTab) {
        // Skip tabs inside the localized-fields class
        if (selectedTab.closest('.localized-fields')) break;

        const tabTarget = this.element.querySelector(`${selectedTab.dataset.bsTarget}`);
        const tabPanes = this.element.querySelectorAll('.nav-tab-pane');

        this.tabTargets.forEach((tab) => {
          tab.classList.remove('active');
        });
        selectedTab.classList.add('active');

        tabPanes.forEach((pane) => {
          pane.classList.remove('active');
          pane.classList.remove('show');
        });

        if (tabTarget) {
          tabTarget.classList.add('active');
          tabTarget.classList.add('show');
        }

        // Check if the selected tab is nested and activate its parent tab
        const parentTabPane = selectedTab.closest('.nav-tab-pane');
        if (parentTabPane) {
          const parentTab = this.element.querySelector(`[data-bs-target="#${parentTabPane.id}"]`);
          selectedTab = parentTab; // Move up to the parent tab for the next iteration
        } else {
          selectedTab = null; // Exit the loop if no parent tab exists
        }
      }

      // Reset the hash to prevent re-triggering on the same tab
      history.replaceState({}, document.title, window.location.pathname + window.location.search);
    }
  }

  setupTabChangeListener() {
    this.tabTargets.forEach((link) => {
      if (link.closest('.localized-fields')) return;

      link.addEventListener("shown.bs.tab", (event) => {
        const targetHash = event.target.getAttribute("data-bs-target");
        if (targetHash) {
          history.pushState({}, "", targetHash); // Add the hash to the address bar
        }
      });
    });
  }
}