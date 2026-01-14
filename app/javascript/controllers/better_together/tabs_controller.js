import { Controller } from "@hotwired/stimulus";

// filepath: app/javascript/controllers/better_together/tabs_controller.js

export default class extends Controller {
  static targets = ["tab"];

  connect() {
    this.allTabs = this.getOwnedTabs();
    this.allPanes = this.getOwnedPanes();

    this.activateTabFromHash();
    this.setupTabChangeListener();
  }

  activateTabFromHash() {
    const hash = window.location.hash;
    if (hash) {
      const selectedTab = this.allTabs.find((tab) => this.matchesHash(tab, hash));

      if (selectedTab && !selectedTab.closest('.localized-fields')) {
        if (this.isAllTab(selectedTab)) {
          this.showAllForTab(selectedTab);
        } else {
          // Let Bootstrap handle the tab activation
          const tabInstance = new bootstrap.Tab(selectedTab);
          tabInstance.show();
        }
        return;
      }

      const pane = this.findPaneForHash(hash);
      if (!pane) return;

      const paneTab = this.findTabForPane(pane);
      if (paneTab && !paneTab.closest('.localized-fields')) {
        const tabInstance = new bootstrap.Tab(paneTab);
        tabInstance.show();
      }
    }
  }

  setupTabChangeListener() {
    // Use the unified collection of all available tabs
    const tabsToSetup = this.allTabs || [];

    tabsToSetup.forEach((link) => {
      if (link.closest('.localized-fields')) return;

      if (this.isAllTab(link)) {
        link.addEventListener("click", (event) => {
          event.preventDefault();
          this.showAllForTab(link);
        });
      } else {
        // Primary: Listen for click events
        link.addEventListener("click", (event) => {
          if (this.allTabsActive()) {
            event.preventDefault();
            event.stopPropagation();

            this.resetAllPanes();
            this.resetAllTabsState();
            this.setAllTabsActive(false);

            const targetHash = link.getAttribute("href") || link.getAttribute("data-bs-target");
            const tabInstance = new bootstrap.Tab(link);
            tabInstance.show();

            if (targetHash && targetHash.startsWith('#')) {
              history.pushState({}, "", targetHash);
            }

            return;
          }

          const targetHash = link.getAttribute("href") || link.getAttribute("data-bs-target");

          if (targetHash && targetHash.startsWith('#')) {
            // Update immediately - no delay needed
            history.pushState({}, "", targetHash);
          }
        });
      }
    });
  }

  getOwnedTabs() {
    const tabs = this.tabTargets.length > 0
      ? this.tabTargets
      : Array.from(this.element.querySelectorAll('[data-bs-toggle="tab"]'));

    return tabs.filter((tab) => this.ownedByThisController(tab));
  }

  ownedByThisController(tab) {
    const owner = tab.closest('[data-controller~="better_together--tabs"]');
    return owner === this.element;
  }

  matchesHash(tab, hash) {
    return tab.getAttribute("href") === hash ||
      tab.getAttribute("data-bs-target") === hash ||
      tab.getAttribute("data-better_together--tabs-hash") === hash;
  }

  findPaneForHash(hash) {
    const element = this.element.querySelector(hash);
    if (!element) return null;

    let pane = element.closest(".tab-pane");
    while (pane) {
      const owner = pane.closest('[data-controller~="better_together--tabs"]');
      if (owner === this.element) return pane;
      pane = pane.parentElement?.closest(".tab-pane");
    }

    return null;
  }

  findTabForPane(pane) {
    return this.allTabs.find((tab) => {
      const target = tab.getAttribute("href") || tab.getAttribute("data-bs-target");
      return target === `#${pane.id}`;
    });
  }

  getOwnedPanes() {
    const panes = Array.from(this.element.querySelectorAll(".tab-pane"));
    return panes.filter((pane) => {
      const owner = pane.closest('[data-controller~="better_together--tabs"]');
      return owner === this.element;
    });
  }

  isAllTab(tab) {
    return tab.getAttribute("data-better_together--tabs-mode") === "all";
  }

  showAllForTab(tab) {
    this.resetAllTabsState();
    tab.classList.add("active");
    tab.setAttribute("aria-selected", "true");
    this.setAllTabsActive(true);

    this.allPanes.forEach((pane) => {
      pane.classList.add("show");
      pane.classList.add("active");
    });

    const hash = tab.getAttribute("data-better_together--tabs-hash");
    if (hash) {
      history.pushState({}, "", hash);
    }
  }

  resetAllPanes() {
    this.allPanes.forEach((pane) => {
      pane.classList.remove("show");
      pane.classList.remove("active");
    });
  }

  resetAllTabsState() {
    this.allTabs.forEach((tab) => {
      tab.classList.remove("active");
      tab.setAttribute("aria-selected", "false");
    });
  }

  allTabsActive() {
    return this.element.dataset.allTabsActive === "true";
  }

  setAllTabsActive(active) {
    this.element.dataset.allTabsActive = active ? "true" : "false";
  }
}
