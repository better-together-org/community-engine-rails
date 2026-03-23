import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "container",
    "template",
    "hostField",
    "newHostSection",
    "hostTypeRadio",
    "hostSelect",
    "removeButton",
    "announcement"
  ]

  static values = {
    availableHostsUrl: String
  }

  connect() {
    // Load options for any new host fields that are already on the page
    this.loadOptionsForNewFields()
    
    // Update remove button states on connect
    this.updateRemoveButtonStates()
  }

  add(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime())
    this.containerTarget.insertAdjacentHTML('beforeend', content)
    
    // Load options for the newly added field
    this.loadOptionsForNewFields()
    
    // Update remove button states
    this.updateRemoveButtonStates()
    
    // Focus on the first radio button in the new field
    const newFields = this.containerTarget.querySelectorAll('.nested-fields[data-new-record="true"]')
    const latestField = newFields[newFields.length - 1]
    if (latestField) {
      const firstRadio = latestField.querySelector('input[type="radio"]')
      if (firstRadio) {
        firstRadio.focus()
      }
    }
  }

  remove(event) {
    event.preventDefault()
    
    const item = event.target.closest('.nested-fields')
    const isNewRecord = item.dataset.newRecord === 'true'
    
    // Allow removing new (unsaved) hosts freely
    if (isNewRecord) {
      item.remove()
      this.announce(this.getTranslation('host_removed'))
      this.updateRemoveButtonStates()
      return
    }
    
    // For existing hosts, check if there's at least one other valid host
    const validHostsCount = this.countValidHosts(item)
    
    if (validHostsCount === 0) {
      // Prevent removal of the last valid host
      this.announce(this.getTranslation('cannot_remove_last'))
      
      // Disable the remove button
      const button = event.target.closest('button')
      if (button) {
        button.setAttribute('aria-disabled', 'true')
        button.classList.add('disabled')
      }
      
      return
    }
    
    // Mark existing host for destruction
    const destroyInput = item.querySelector('input[name*="_destroy"]')
    if (destroyInput) {
      destroyInput.value = '1'
      item.style.display = 'none'
      this.announce(this.getTranslation('host_removed'))
    }
    
    // Update remove button states after removal
    this.updateRemoveButtonStates()
  }

  hostTypeChanged(event) {
    const radio = event.target
    const hostField = radio.closest('.nested-fields')
    const selectElement = hostField.querySelector('[data-better-together--event-hosts-target="hostSelect"]')
    
    console.log('Host type changed:', radio.value)
    console.log('Select element found:', selectElement)
    
    if (!selectElement) {
      console.warn('No select element found for host type change')
      return
    }
    
    const hostType = radio.value
    console.log('Loading options for host type:', hostType)
    this.loadHostOptions(selectElement, hostType)
  }

  hostSelectChanged(event) {
    // Update remove button states when host selection changes
    this.updateRemoveButtonStates()
  }

  loadOptionsForNewFields() {
    // Find all new host fields (data-new-record="true")
    const newFields = this.containerTarget.querySelectorAll('.nested-fields[data-new-record="true"]')
    
    newFields.forEach(field => {
      const selectElement = field.querySelector('[data-better-together--event-hosts-target="hostSelect"]')
      if (!selectElement) return
      
      // Find the checked radio button for this field
      const checkedRadio = field.querySelector('input[type="radio"][data-better-together--event-hosts-target="hostTypeRadio"]:checked')
      if (checkedRadio) {
        this.loadHostOptions(selectElement, checkedRadio.value)
      }
    })
  }

  async loadHostOptions(selectElement, hostType) {
    if (!selectElement || !hostType) return
    
    try {
      // Show loading state
      selectElement.innerHTML = `<option value="">${this.getTranslation('loading')}</option>`
      selectElement.disabled = true
      
      // Build the URL - use the value from data attribute or construct from current path
      let baseUrl = this.hasAvailableHostsUrlValue ? this.availableHostsUrlValue : null
      if (!baseUrl) {
        // Extract locale and construct URL from current path
        const pathParts = window.location.pathname.split('/')
        const locale = pathParts[1] || 'en'
        baseUrl = `/${locale}/events/available_hosts`
      }
      
      // Fetch available hosts for this type
      const url = `${baseUrl}?host_type=${encodeURIComponent(hostType)}`
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error('Failed to load hosts')
      }
      
      const hosts = await response.json()
      
      // Clear and populate select options
      selectElement.innerHTML = `<option value="">${this.getTranslation('select_placeholder')}</option>`
      hosts.forEach(host => {
        const option = document.createElement('option')
        option.value = host.value
        option.textContent = host.text
        selectElement.appendChild(option)
      })
      
      selectElement.disabled = false
      
      // Trigger change event to update any listeners
      selectElement.dispatchEvent(new Event('change', { bubbles: true }))
      
      // If this select has SlimSelect initialized, we need to reinitialize it with new data
      // SlimSelect will auto-initialize via its controller when the DOM updates
      
    } catch (error) {
      console.error('Error loading host options:', error)
      selectElement.innerHTML = `<option value="">${this.getTranslation('error_loading')}</option>`
      selectElement.disabled = false
    }
  }

  countVisibleHosts() {
    const allFields = this.containerTarget.querySelectorAll('.nested-fields')
    let count = 0
    
    allFields.forEach(field => {
      const isHidden = field.style.display === 'none'
      const isDestroyed = field.querySelector('input[name*="_destroy"]')?.value === '1'
      
      if (!isHidden && !isDestroyed) {
        count++
      }
    })
    
    return count
  }

  countValidHosts(excludeField = null) {
    // Count hosts that have both type and id selected (excluding the field being removed)
    const allFields = this.containerTarget.querySelectorAll('.nested-fields')
    let count = 0
    
    allFields.forEach(field => {
      // Skip the field being removed
      if (excludeField && field === excludeField) return
      
      const isHidden = field.style.display === 'none'
      const isDestroyed = field.querySelector('input[name*="_destroy"]')?.value === '1'
      const isNewRecord = field.dataset.newRecord === 'true'
      
      // Skip hidden or destroyed fields
      if (isHidden || isDestroyed) return
      
      // For existing records, they already have valid host data
      if (!isNewRecord) {
        count++
        return
      }
      
      // For new records, check if they have both type and id selected
      const hostTypeRadio = field.querySelector('input[type="radio"][data-better-together--event-hosts-target="hostTypeRadio"]:checked')
      const hostSelect = field.querySelector('select[data-better-together--event-hosts-target="hostSelect"]')
      
      if (hostTypeRadio && hostSelect && hostSelect.value !== '') {
        count++
      }
    })
    
    return count
  }

  updateRemoveButtonStates() {
    const allFields = this.containerTarget.querySelectorAll('.nested-fields')
    
    allFields.forEach(field => {
      const removeButton = field.querySelector('[data-better-together--event-hosts-target="removeButton"]')
      if (!removeButton) return
      
      const isNewRecord = field.dataset.newRecord === 'true'
      
      // New records can always be removed
      if (isNewRecord) {
        removeButton.removeAttribute('aria-disabled')
        removeButton.classList.remove('disabled')
        return
      }
      
      // For existing records, check if there are other valid hosts
      const validHostsCount = this.countValidHosts(field)
      
      if (validHostsCount === 0) {
        removeButton.setAttribute('aria-disabled', 'true')
        removeButton.classList.add('disabled')
      } else {
        removeButton.removeAttribute('aria-disabled')
        removeButton.classList.remove('disabled')
      }
    })
  }

  announce(message) {
    if (this.hasAnnouncementTarget) {
      this.announcementTarget.textContent = message
      
      // Clear after a delay
      setTimeout(() => {
        this.announcementTarget.textContent = ''
      }, 3000)
    }
  }

  getTranslation(key) {
    const translations = {
      'cannot_remove_last': 'Cannot remove the last host. Please add another host first.',
      'host_removed': 'Host removed',
      'loading': 'Loading...',
      'select_placeholder': 'Select a host',
      'error_loading': 'Error loading hosts'
    }
    
    // Convert snake_case key to the exact format used in dataset (with hyphens)
    // e.g., 'select_placeholder' -> 'betterTogether-EventHostsSelectPlaceholderText'
    const words = key.split('_')
    const capitalizedWords = words.map(word => word.charAt(0).toUpperCase() + word.slice(1))
    const dataKey = `betterTogether-EventHosts${capitalizedWords.join('')}Text`
    
    return this.element.dataset[dataKey] || translations[key] || key
  }
}
