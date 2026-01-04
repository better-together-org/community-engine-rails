import { Controller } from '@hotwired/stimulus';
import 'slim-select';

export default class extends Controller {
  static values = {
    options: Object
  }

  static targets = []

  connect() {
    console.log('SlimSelect controller connecting...', this.element);
    console.log('Options value:', this.optionsValue);
    console.log('Has options value:', this.hasOptionsValue);
    console.log('Element dataset:', this.element.dataset);
    console.log('All data attributes:', Object.keys(this.element.dataset));
    
    // Store whether this was originally required for our custom validation
    this.wasRequired = this.element.hasAttribute('required');
    
    // Remove the required attribute from the original select to prevent browser validation conflicts
    if (this.wasRequired) {
      this.element.removeAttribute('required');
    }
    
    // Add form submission listener to validate SlimSelect before submit
    this.addFormValidationListener();
    
    // Add form reset listener to properly reset SlimSelect
    this.addFormResetListener();
    
    // Try to get options from data attribute directly if Stimulus value fails
    let optionsData = {};
    if (this.hasOptionsValue) {
      optionsData = this.optionsValue;
    } else {
      // Fallback: try to parse the data attribute directly
      const optionsAttr = this.element.dataset.betterTogether__slimSelectOptionsValue ||
                         this.element.dataset.betterTogetherSlimSelectOptionsValue ||
                         this.element.getAttribute('data-better-together--slim-select-options-value') ||
                         this.element.getAttribute('data-better_together--slim-select-options-value');
      
      console.log('Looking for data attribute, found:', optionsAttr);
      
      if (optionsAttr) {
        try {
          optionsData = JSON.parse(optionsAttr);
          console.log('Parsed options from data attribute:', optionsData);
        } catch (e) {
          console.error('Failed to parse options from data attribute:', e);
        }
      }
    }
    
    const defaultOptions = {
      settings: {
        allowDeselect: true,
        searchPlaceholder: 'Search...',
        searchHighlight: true,
        closeOnSelect: true,
        openPosition: 'down',
        addToBody: false  // Keep dropdown inside modal to avoid focus issues
      }
    };

    // Merge with custom options from the element
    const options = { ...defaultOptions, ...optionsData };
    console.log('Final options:', options);

    // Handle AJAX configuration if present
    if (options.ajax) {
      console.log('Configuring AJAX for SlimSelect with URL:', options.ajax.url);
      
      // Configure SlimSelect with proper AJAX settings
      options.settings.searchFilter = false; // Disable client-side filtering
      
      options.events = {
        search: (search, currentData) => {
          console.log('SlimSelect search triggered:', search, 'currentData:', currentData);
          
          return new Promise((resolve, reject) => {
            const url = new URL(options.ajax.url, window.location.origin);
            
            // Add cache-busting timestamp to prevent stale results
            url.searchParams.append('_', Date.now().toString());
            
            // Add search parameter if search term is provided
            if (search && search.trim().length > 0) {
              url.searchParams.append('search', search.trim());
            }

            console.log('Making AJAX request to:', url.toString());

            fetch(url.toString(), {
              method: 'GET',
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest',
                'Cache-Control': 'no-cache'
              }
            })
            .then(response => {
              console.log('AJAX response:', response);
              return response.json();
            })
            .then(data => {
              console.log('AJAX data received:', data);
              resolve(data);
            })
            .catch(error => {
              console.error('SlimSelect AJAX error:', error);
              reject(error);
            });
          });
        },
        beforeOpen: () => {
          console.log('SlimSelect beforeOpen event');
          
          // Clear any previous validation errors when opening
          this.element.setCustomValidity('');
          
          // Reset the select to empty state
          this.element.value = '';
          
          // Force refresh of data every time modal opens to ensure current membership state
          console.log('Forcing refresh of SlimSelect data on modal open');
          
          // Clear existing options except prompt to force fresh data
          const promptOption = this.element.querySelector('option[value=""]');
          this.element.innerHTML = '';
          if (promptOption) {
            this.element.appendChild(promptOption.cloneNode(true));
          } else {
            // Create a prompt option if one doesn't exist
            const newPromptOption = new Option('Search for people...', '', false, false);
            this.element.appendChild(newPromptOption);
          }
          
          // Reset SlimSelect to show the prompt
          if (this.slimSelect && typeof this.slimSelect.set === 'function') {
            this.slimSelect.set('');
          }
          
          // Reload fresh results
          this.loadInitialResults(options.ajax.url);
          
          // Prevent modal focus trap from interfering
          if (this.isInsideModal()) {
            this.preventModalFocusTrap();
          }
        },
        afterClose: () => {
          console.log('SlimSelect afterClose event');
          // Restore modal focus trap
          if (this.isInsideModal()) {
            this.restoreModalFocusTrap();
          }
        },
        afterChange: (newVal) => {
          console.log('SlimSelect afterChange event:', newVal);
          // Ensure the original select element is properly updated
          if (newVal && newVal.length > 0) {
            this.element.value = newVal[0].value;
            // Clear any validation errors since we have a selection
            this.element.setCustomValidity('');
            // Trigger change event for form validation
            this.element.dispatchEvent(new Event('change', { bubbles: true }));
          } else {
            this.element.value = '';
            // Set custom validation message if this field was originally required
            if (this.wasRequired) {
              this.element.setCustomValidity('Please select a person.');
            }
            this.element.dispatchEvent(new Event('change', { bubbles: true }));
          }
        }
      };
    }

    console.log('Creating SlimSelect with options:', options);
    
    this.slimSelect = new SlimSelect({
      select: this.element,
      ...options
    });

    console.log('SlimSelect created:', this.slimSelect);

    // Ensure SlimSelect reflects any pre-selected options rendered by the server
    // (useful when Turbo or server-side rendering supplies selected attributes)
    try {
      if (this.slimSelect && typeof this.slimSelect.set === 'function') {
        // Pass current selected values from the underlying select
        const selected = Array.from(this.element.selectedOptions).map(o => o.value);
        this.slimSelect.set(selected);
        console.log('Set SlimSelect selected values:', selected);
      }
    } catch (e) {
      // Fail silently - SlimSelect might not support set() in some versions
      console.warn('Unable to refresh SlimSelect selected values:', e);
    }
  }

  loadInitialResults(url) {
    // Fetch initial results without search term to populate dropdown
    const fullUrl = new URL(url, window.location.origin);
    // Add timestamp to prevent caching
    fullUrl.searchParams.append('_', Date.now().toString());
    
    return fetch(fullUrl.toString(), {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      // Clear existing options except the prompt
      const existingOptions = Array.from(this.element.options);
      const promptOption = existingOptions.find(opt => opt.value === '');
      
      // Clear all options
      this.element.innerHTML = '';
      
      // Re-add prompt option if it existed
      if (promptOption) {
        this.element.appendChild(promptOption.cloneNode(true));
      }
      
      // Add initial options to the select element
      data.forEach(item => {
        const option = new Option(item.text, item.value, false, false);
        this.element.add(option);
      });
      
      // Refresh SlimSelect to show the new options
      if (this.slimSelect && typeof this.slimSelect.setData === 'function') {
        const promptText = promptOption ? promptOption.textContent : 'Search for people...';
        this.slimSelect.setData([
          { text: promptText, value: '' },
          ...data
        ]);
      }
      
      return data;
    })
    .catch(error => {
      console.error('SlimSelect initial load error:', error);
      return [];
    });
  }

  disconnect() {
    if (this.slimSelect) {
      this.slimSelect.destroy();
    }
  }

  // Helper method to check if element is inside a Bootstrap modal
  isInsideModal() {
    return this.element.closest('.modal') !== null;
  }

  // Temporarily disable modal focus trap when SlimSelect opens
  preventModalFocusTrap() {
    const modal = this.element.closest('.modal');
    if (modal) {
      // Store original tabindex values and disable focus trap temporarily
      this.originalTabIndex = modal.getAttribute('tabindex');
      modal.removeAttribute('tabindex');
      
      // Prevent Bootstrap modal from stealing focus
      modal.style.pointerEvents = 'none';
      
      // Allow the SlimSelect dropdown area to receive events
      setTimeout(() => {
        const slimSelectContent = document.querySelector('[data-id="' + this.element.id + '"]');
        if (slimSelectContent) {
          slimSelectContent.style.pointerEvents = 'auto';
        }
      }, 10);
    }
  }

  // Restore modal focus trap when SlimSelect closes
  restoreModalFocusTrap() {
    const modal = this.element.closest('.modal');
    if (modal) {
      modal.style.pointerEvents = 'auto';
      
      // Restore original tabindex if it existed
      if (this.originalTabIndex !== null) {
        modal.setAttribute('tabindex', this.originalTabIndex);
      } else {
        modal.setAttribute('tabindex', '-1');
      }
    }
  }

  // Add form validation listener to check SlimSelect value on submit
  addFormValidationListener() {
    const form = this.element.closest('form');
    if (form) {
      form.addEventListener('submit', (event) => {
        if (this.wasRequired && (!this.element.value || this.element.value === '')) {
          event.preventDefault();
          this.element.setCustomValidity('Please select a person.');
          // Focus the SlimSelect instead of the hidden original select
          const slimSelectEl = form.querySelector(`[data-id="${this.element.dataset.id || 'ss-' + this.element.id}"]`);
          if (slimSelectEl) {
            slimSelectEl.focus();
          }
          this.element.reportValidity();
        } else {
          this.element.setCustomValidity('');
        }
      });
    }
  }

  // Add form reset listener to handle form resets properly
  addFormResetListener() {
    const form = this.element.closest('form');
    if (form) {
      form.addEventListener('reset', () => {
        setTimeout(() => {
          // Reset SlimSelect after form reset
          this.element.value = '';
          this.element.setCustomValidity('');
          if (this.slimSelect && typeof this.slimSelect.set === 'function') {
            this.slimSelect.set('');
          }
        }, 10); // Small delay to let form reset complete first
      });

      // Also listen for change events on our element to handle programmatic resets
      this.element.addEventListener('change', () => {
        if (this.slimSelect && typeof this.slimSelect.set === 'function' && this.element.value === '') {
          this.slimSelect.set('');
        }
      });
    }
  }
}
