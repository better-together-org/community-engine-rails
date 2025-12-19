import { Controller } from '@hotwired/stimulus';
import 'slim-select';

export default class extends Controller {
  static values = {
    options: Object
  }

  connect() {
    const defaultOptions = {
      settings: {
        allowDeselect: true,
        searchPlaceholder: 'Search...',
        searchHighlight: true,
        closeOnSelect: true
      }
    };

    // Merge with custom options from the element
    const options = { ...defaultOptions, ...this.optionsValue };

    // Handle AJAX configuration if present
    if (options.ajax) {
      // Fetch initial results when the select opens
      this.fetchInitialResults(options.ajax.url);

      options.events = {
        search: (search, currentData) => {
          if (search.length < 2) {
            return new Promise((resolve) => {
              resolve([]);
            });
          }

          return new Promise((resolve, reject) => {
            const url = new URL(options.ajax.url, window.location.origin);
            url.searchParams.append('search', search);

            fetch(url.toString(), {
              method: 'GET',
              headers: {
                'Accept': 'application/json',
                'Content-Type': 'application/json',
                'X-Requested-With': 'XMLHttpRequest'
              }
            })
            .then(response => response.json())
            .then(data => {
              resolve(data);
            })
            .catch(error => {
              console.error('SlimSelect AJAX error:', error);
              reject(error);
            });
          });
        }
      };
    }

    this.slimSelect = new SlimSelect({
      select: this.element,
      ...options
    });

    // Ensure SlimSelect reflects any pre-selected options rendered by the server
    // (useful when Turbo or server-side rendering supplies selected attributes)
    try {
      if (this.slimSelect && typeof this.slimSelect.set === 'function') {
        // Pass current selected values from the underlying select
        const selected = Array.from(this.element.selectedOptions).map(o => o.value);
        this.slimSelect.set(selected);
      }
    } catch (e) {
      // Fail silently - SlimSelect might not support set() in some versions
      console.warn('Unable to refresh SlimSelect selected values:', e);
    }
  }

  fetchInitialResults(url) {
    // Fetch initial results without search term to populate dropdown
    fetch(url, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'X-Requested-With': 'XMLHttpRequest'
      }
    })
    .then(response => response.json())
    .then(data => {
      // Add initial options to the select element
      data.forEach(item => {
        const option = new Option(item.text, item.value, false, false);
        this.element.add(option);
      });
      
      // Refresh SlimSelect to show the new options
      if (this.slimSelect && typeof this.slimSelect.setData === 'function') {
        this.slimSelect.setData(data);
      }
    })
    .catch(error => {
      console.error('SlimSelect initial load error:', error);
    });
  }

  disconnect() {
    if (this.slimSelect) {
      this.slimSelect.destroy();
    }
  }
}
