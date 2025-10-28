import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = []

  connect() {
    console.log('Translation Manager controller connected');
    
    // Handle tab activation for lazy loading
    this.bindTabEvents();
  }

  bindTabEvents() {
    const tabButtons = document.querySelectorAll('#translationTabs button[data-bs-toggle="tab"]');
    
    tabButtons.forEach(tab => {
      tab.addEventListener('shown.bs.tab', (event) => {
        const tabId = event.target.getAttribute('aria-controls');
        console.log(`Tab activated: ${tabId}`);
        
        // Each tab has its own turbo frame that will automatically load via lazy loading
        // The src attribute on each turbo frame handles the loading
      });
    });
  }

  // Tab switching is now handled by Bootstrap and Turbo Frames
  // Each tab loads its content independently via lazy loading
}