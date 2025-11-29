import AppController from "controllers/better_together/app_controller"

export default class extends AppController {
  static targets = [ "select" ]

  connect() {
    // super.connect() // Initialize debug and other base functionality
    
    this.debug.log('Controller connected')
    
    // Get the IANA timezone identifier from the browser
    const ianaTimeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;
    this.debug.log('Browser IANA timezone:', ianaTimeZone)
    
    // Map IANA timezone to Rails timezone name
    const railsTimeZone = this.mapIANAToRails(ianaTimeZone);
    this.debug.log('Mapped to Rails timezone:', railsTimeZone)

    if (this.hasSelectTarget && railsTimeZone) {
      const options = this.selectTarget.options;
      this.debug.log('Total timezone options:', options.length)
      
      // Find matching option by value
      for (let i = 0; i < options.length; i++) {
        if (options[i].value === railsTimeZone) {
          this.debug.log('Match found at index:', i, 'Rails name:', railsTimeZone)
          this.selectTarget.selectedIndex = i;
          break;
        }
      }
      
      this.debug.log('Final selected index:', this.selectTarget.selectedIndex)
      this.debug.log('Final selected value:', this.selectTarget.value)
    } else if (!this.hasSelectTarget) {
      this.debug.warn('Select target NOT found!')
    } else {
      this.debug.warn('Could not map IANA timezone to Rails timezone:', ianaTimeZone)
    }
  }
  
  // Map IANA timezone identifiers to Rails timezone names
  // This is a subset of common mappings - Rails uses TZInfo under the hood
  mapIANAToRails(ianaZone) {
    const mapping = {
      'America/St_Johns': 'Newfoundland',
      'America/Halifax': 'Atlantic Time (Canada)',
      'America/New_York': 'Eastern Time (US & Canada)',
      'America/Chicago': 'Central Time (US & Canada)',
      'America/Denver': 'Mountain Time (US & Canada)',
      'America/Phoenix': 'Arizona',
      'America/Los_Angeles': 'Pacific Time (US & Canada)',
      'America/Anchorage': 'Alaska',
      'Pacific/Honolulu': 'Hawaii',
      'Europe/London': 'London',
      'Europe/Paris': 'Paris',
      'Europe/Berlin': 'Berlin',
      'Europe/Rome': 'Rome',
      'Europe/Madrid': 'Madrid',
      'Europe/Amsterdam': 'Amsterdam',
      'Europe/Brussels': 'Brussels',
      'Europe/Vienna': 'Vienna',
      'Europe/Warsaw': 'Warsaw',
      'Europe/Prague': 'Prague',
      'Europe/Stockholm': 'Stockholm',
      'Europe/Copenhagen': 'Copenhagen',
      'Europe/Athens': 'Athens',
      'Europe/Helsinki': 'Helsinki',
      'Europe/Dublin': 'Dublin',
      'Europe/Lisbon': 'Lisbon',
      'Europe/Moscow': 'Moscow',
      'Asia/Tokyo': 'Tokyo',
      'Asia/Seoul': 'Seoul',
      'Asia/Shanghai': 'Beijing',
      'Asia/Hong_Kong': 'Hong Kong',
      'Asia/Singapore': 'Singapore',
      'Asia/Bangkok': 'Bangkok',
      'Asia/Dubai': 'Abu Dhabi',
      'Asia/Kolkata': 'Kolkata',
      'Asia/Karachi': 'Karachi',
      'Asia/Tehran': 'Tehran',
      'Asia/Jerusalem': 'Jerusalem',
      'Asia/Istanbul': 'Istanbul',
      'Australia/Sydney': 'Sydney',
      'Australia/Melbourne': 'Melbourne',
      'Australia/Brisbane': 'Brisbane',
      'Australia/Adelaide': 'Adelaide',
      'Australia/Perth': 'Perth',
      'Pacific/Auckland': 'Auckland',
      'America/Toronto': 'Eastern Time (US & Canada)',
      'America/Vancouver': 'Pacific Time (US & Canada)',
      'America/Mexico_City': 'Mexico City',
      'America/Sao_Paulo': 'Brasilia',
      'America/Buenos_Aires': 'Buenos Aires',
      'America/Lima': 'Lima',
      'America/Bogota': 'Bogota',
      'America/Santiago': 'Santiago',
      'America/Caracas': 'Caracas',
      'Africa/Cairo': 'Cairo',
      'Africa/Johannesburg': 'Pretoria',
      'Africa/Nairobi': 'Nairobi'
    };
    
    return mapping[ianaZone] || null;
  }
}
