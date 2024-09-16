import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "tab", "tabButton", "tabContent", "trix"];

  connect() {
    this.element.setAttribute("novalidate", true); // Disable default HTML5 validation

    // Listen for the custom event that syncs the locale across field groups
    window.addEventListener("locale:sync", this.handleLocaleSync.bind(this));

    // Listen for input changes to update the translation status dynamically
    this.inputTargets.forEach((input) => {
      input.addEventListener("input", this.updateTranslationStatus.bind(this));
    });

    // Listen for Trix editor changes to update the translation status
    this.trixTargets.forEach((trix) => {
      trix.addEventListener("trix-change", this.updateTrixTranslationStatus.bind(this));
    });

    this.updateTranslationStatus(); // Initial update of translation status
  }

  // Cleanup when the controller disconnects
  disconnect() {
    window.removeEventListener("locale:sync", this.handleLocaleSync.bind(this));
    this.inputTargets.forEach((input) => {
      input.removeEventListener("input", this.updateTranslationStatus.bind(this));
    });
    this.trixTargets.forEach((trix) => {
      trix.removeEventListener("trix-change", this.updateTrixTranslationStatus.bind(this));
    });
  }

  // This method will be called whenever regular input changes
  updateTranslationStatus(event) {
    this.inputTargets.forEach((input) => {
      const localeTabId = input.closest(".tab-pane").getAttribute("aria-labelledby");
      const tabButton = document.getElementById(localeTabId);

      if (input.value.trim() === "") {
        // If the field is empty, show the "no translation" indicator
        this.setTranslationIndicator(tabButton, false);
      } else {
        // If the field has content, show the "translation available" indicator
        this.setTranslationIndicator(tabButton, true);
      }
    });
  }

  // This method will be called whenever Trix content changes
  updateTrixTranslationStatus(event) {
    const trixElement = event.target;
    const localeTabId = trixElement.closest(".tab-pane").getAttribute("aria-labelledby");
    const tabButton = document.getElementById(localeTabId);

    if (trixElement.editor.getDocument().toString().trim() === "") {
      // If the Trix field is empty, show the "no translation" indicator
      this.setTranslationIndicator(tabButton, false);
    } else {
      // If the Trix field has content, show the "translation available" indicator
      this.setTranslationIndicator(tabButton, true);
    }
  }

  // Helper method to set the translation indicator for a tab button
  setTranslationIndicator(tabButton, isTranslated) {
    const iTag = tabButton.querySelector("i");
    if (isTranslated) {
      iTag.classList.replace("fa-exclamation-circle", "fa-check-circle");
      tabButton.classList.add("text-success");
      iTag.classList.remove("text-muted");
      iTag.title = "Translation available";
      tabButton.querySelector(".visually-hidden").textContent = "Translation available";
    } else {
      iTag.classList.replace("fa-check-circle", "fa-exclamation-circle");
      tabButton.classList.remove("text-success");
      iTag.classList.add("text-muted");
      iTag.title = "No translation available";
      tabButton.querySelector(".visually-hidden").textContent = "No translation available";
    }
  }

  // Sync the selected locale tab across all translatable field groups
  syncLocaleAcrossFields(event) {
    const selectedLocale = event.currentTarget.dataset.locale;

    // Emit a custom event with the selected locale
    const syncEvent = new CustomEvent("locale:sync", {
      detail: { locale: selectedLocale },
    });

    window.dispatchEvent(syncEvent); // Emit the event globally

    this.updateActiveTab(selectedLocale); // Update the current group's tabs
  }

  // Event handler for syncing tabs across groups
  handleLocaleSync(event) {
    const { locale } = event.detail;
    this.updateActiveTab(locale); // Update all field groups to use the selected locale
    this.updateActiveTabContent(locale); // Update all field groups to use the selected locale
  }

  // Updates the active tab and shows/hides content for the current field group
  updateActiveTab(selectedLocale) {
    this.tabTargets.forEach((tab) => {
      const locale = tab.dataset.locale;

      // Find the button for the current tab
      const tabButton = tab.querySelector(`button[data-locale="${locale}"]`);

      if (tabButton) {
        if (locale === selectedLocale) {
          // Show the tab for the selected locale
          tabButton.classList.add("active");
          tabButton.setAttribute("aria-selected", "true");
        } else {
          // Hide the tab for non-selected locales
          tabButton.classList.remove("active");
          tabButton.setAttribute("aria-selected", "false");
        }
      }
    });

    // Separate logic to update content visibility
    this.updateActiveTabContent(selectedLocale);
  }

  // Method to show/hide the content pane based on the selected locale
  updateActiveTabContent(selectedLocale) {
    this.tabContentTargets.forEach((contentPane) => {
      const locale = contentPane.dataset.locale;

      if (locale === selectedLocale) {
        // Show the content area for the selected locale
        contentPane.classList.add("show", "active");
      } else {
        // Hide the content area for non-selected locales
        contentPane.classList.remove("show", "active");
      }
    });
  }
}
