import { Controller } from "@hotwired/stimulus";
import * as bootstrap from "bootstrap";

// filepath: app/javascript/controllers/better_together/tabs_controller.js

export default class extends Controller {
  static targets = ["tab"];

  connect() {
    // this.initializeFirstTabs();
    this.activateTabFromHash();
    this.setupTabChangeListener();
  }

  // initializeFirstTabs() {
  //   // Ensure the first tab in each group is active and shown
  //   const tabGroups = this.element.querySelectorAll('[data-bs-target]');
  //   tabGroups.forEach((tab) => {
  //     // Skip tabs inside the localized-fields class
  //     if (tab.closest('.localized-fields')) return;

  //     const tabPane = this.element.querySelector(tab.dataset.bsTarget);
  //     if (tabPane) {
  //       const nestedTabs = tabPane.querySelectorAll('[data-bs-target]');
  //       if (nestedTabs.length > 0) {
  //         const firstNestedTab = nestedTabs[0];
  //         const firstNestedTabTarget = tabPane.querySelector(firstNestedTab.dataset.bsTarget);

  //         nestedTabs.forEach((nestedTab) => {
  //           nestedTab.classList.remove('active');
  //         });
  //         firstNestedTab.classList.add('active');

  //         if (firstNestedTabTarget) {
  //           const nestedTabPanes = tabPane.querySelectorAll('.tab-pane');
  //           nestedTabPanes.forEach((nestedPane) => {
  //             nestedPane.classList.remove('active');
  //             nestedPane.classList.remove('show');
  //           });

  //           firstNestedTabTarget.classList.add('active');
  //           firstNestedTabTarget.classList.add('show');
  //         }
  //       }
  //     }
  //   });
  // }

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

          // // Activate the first tab inside the activated tab pane
          // const nestedTabs = tabTarget.querySelectorAll('[data-bs-target]');
          // if (nestedTabs.length > 0) {
          //   const firstNestedTab = nestedTabs[0];
          //   const firstNestedTabTarget = tabTarget.querySelector(firstNestedTab.dataset.bsTarget);

          //   nestedTabs.forEach((nestedTab) => {
          //     nestedTab.classList.remove('active');
          //   });
          //   firstNestedTab.classList.add('active');

          //   if (firstNestedTabTarget) {
          //     const nestedTabPanes = tabTarget.querySelectorAll('.tab-pane');
          //     nestedTabPanes.forEach((nestedPane) => {
          //       nestedPane.classList.remove('active');
          //       nestedPane.classList.remove('show');
          //     });

          //     firstNestedTabTarget.classList.add('active');
          //     firstNestedTabTarget.classList.add('show');
          //   }
          // }
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
    }
  }

  setupTabChangeListener() {
    const tabLinks = this.tabTargets;
    tabLinks.forEach((link) => {
      // Skip tabs inside the localized-fields class
      if (link.closest('.localized-fields')) return;

      link.addEventListener("shown.bs.tab", (event) => {
        history.pushState({}, "", event.target.getAttribute("data-bs-target"))
      });
    });
  }
}