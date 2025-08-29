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
      options.events = {
        search: (search, currentData) => {
          if (search.length < 2) {
            return new Promise((resolve) => {
              resolve([]);
            });
          }

          return new Promise((resolve, reject) => {
            const url = new URL(options.ajax.url, window.location.origin);
            url.searchParams.append('q', search);

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
  }

  disconnect() {
    if (this.slimSelect) {
      this.slimSelect.destroy();
    }
  }
}
