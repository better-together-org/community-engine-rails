import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["aiTranslate", "input", "tab", "tabButton", "tabContent", "trix"];

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

  aiTranslateAttribute(event) {
    event.preventDefault(); // Prevent default link behavior

    // Get data attributes for IDs and locales
    const fieldDivId = event.target.getAttribute("data-field-id");
    const sourceLocale = event.target.getAttribute("data-source-locale");
    const targetLocale = event.target.getAttribute("data-target-locale");
    const baseUrl = event.target.getAttribute("data-base-url");

    // Select the target and source containers based on IDs
    const targetContainer = document.getElementById(fieldDivId);
    const sourceFieldDivId = fieldDivId.replace(targetLocale, sourceLocale);
    const sourceContainer = document.getElementById(sourceFieldDivId);

    if (!targetContainer || !sourceContainer) {
      console.warn("Source or target container not found.");
      return;
    }

    // Helper function to get content based on field type
    const getContent = (container) => {
      if (container.querySelector('trix-editor')) {
        // Get the HTML content of the Trix editor's associated hidden input
        return container.querySelector('trix-editor').value; // Adjusted to get HTML content
      } else if (container.querySelector('input')) {
        return container.querySelector('input').value.trim();
      } else if (container.querySelector('textarea')) {
        return container.querySelector('textarea').value.trim();
      }
      return null;
    };

    // Helper function to set content based on field type
    const setContent = (container, translation) => {
      if (container.querySelector('trix-editor')) {
        const trixEditor = container.querySelector('trix-editor');
        // Decode HTML entities before setting content in Trix editor
        const decodedHTML = new DOMParser().parseFromString(translation, 'text/html').body.innerHTML;
        trixEditor.editor.loadHTML(decodedHTML);
      } else if (container.querySelector('input')) {
        container.querySelector('input').value = translation;
      } else if (container.querySelector('textarea')) {
        container.querySelector('textarea').value = translation;
      }
    };

    // Get the source content
    const content = getContent(sourceContainer);

    if (!content) {
      console.warn("No content to translate.");
      return;
    }

  // Find the closest dropdown-toggle button, then locate the language icon within it
  const dropdownButton = event.target.closest('.input-group').querySelector('.dropdown-toggle');
  const languageIcon = dropdownButton.querySelector('.fa-language');

  // Add the spin class to make the icon rotate
  languageIcon.classList.add('spin-horizontal');

    // Send the content to the backend for translation with both locales
    fetch(baseUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
      },
      body: JSON.stringify({ content, source_locale: sourceLocale, target_locale: targetLocale })
    })
      .then(response => response.json())
      .then(data => {
        if (data.translation) {
          setContent(targetContainer, data.translation);
          // Optional: Update UI indicators if you have them
          // this.setTranslationIndicator(targetContainer.closest(".tab-pane").querySelector(".nav-link.tab-button"), true);
        } else if (data.error) {
          console.error("Translation error:", data.error);
        }
      })
      .catch(error => console.error("Error:", error)).finally(() => {
        // Remove the spin class after request completes
        languageIcon.classList.remove('spin-horizontal');
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
