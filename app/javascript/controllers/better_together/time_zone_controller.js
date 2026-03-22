import AppController from "controllers/better_together/app_controller"

export default class extends AppController {
  static targets = [ "select" ]

  connect() {
    // super.connect() // Initialize debug and other base functionality
    
    this.debug.log('Controller connected')
    
    // Get the IANA timezone identifier from the browser
    const ianaTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    this.debug.log('Browser IANA timezone:', ianaTimeZone)

    if (this.hasSelectTarget && ianaTimeZone) {
      const options = this.selectTarget.options;
      this.debug.log('Total timezone options:', options.length)
      
      // Find matching option by IANA identifier value
      for (let i = 0; i < options.length; i++) {
        if (options[i].value === ianaTimeZone) {
          this.debug.log('Match found at index:', i, 'IANA timezone:', ianaTimeZone)
          this.selectTarget.selectedIndex = i;
          break;
        }
      }
      
      this.debug.log('Final selected index:', this.selectTarget.selectedIndex)
      this.debug.log('Final selected value:', this.selectTarget.value)
    } else if (!this.hasSelectTarget) {
      this.debug.warn('Select target NOT found!')
    } else {
      this.debug.warn('Could not detect browser timezone')
    }
  }
}
