// Stimulus controller for PlatformDomain form.
// Toggles between "subdomain of the host domain" and "custom domain" entry
// modes, and computes the full hostname preview for the subdomain path. Both
// paths ultimately just populate the same real `hostname` field — this
// controller is presentation-layer only, no model/validation changes.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "subdomainRadio",
    "customRadio",
    "subdomainFields",
    "customFields",
    "subdomainLabelInput",
    "hostnameField"
  ]
  static values = { hostApex: String }

  connect() {
    this.toggleKind()
  }

  toggleKind() {
    const useCustom = this.hasCustomRadioTarget && this.customRadioTarget.checked

    if (this.hasSubdomainFieldsTarget) {
      this.subdomainFieldsTarget.classList.toggle('d-none', useCustom)
    }
    if (this.hasCustomFieldsTarget) {
      this.customFieldsTarget.classList.toggle('d-none', !useCustom)
    }

    if (useCustom) {
      // Switching to custom: leave whatever the steward has typed into the
      // real hostname field alone (or clear the subdomain-derived value so
      // it isn't submitted by mistake).
      if (this.hasHostnameFieldTarget && this.hasSubdomainLabelInputTarget &&
          this.hostnameFieldTarget.value === this.suffixedPreview()) {
        this.hostnameFieldTarget.value = ''
      }
    } else {
      this.updateSubdomainPreview()
    }
  }

  updateSubdomainPreview() {
    if (this.hasCustomRadioTarget && this.customRadioTarget.checked) return
    if (!this.hasHostnameFieldTarget) return

    this.hostnameFieldTarget.value = this.suffixedPreview()
  }

  suffixedPreview() {
    if (!this.hasSubdomainLabelInputTarget || !this.hostApexValue) return ''

    const label = this.subdomainLabelInputTarget.value.trim()
    if (!label) return ''

    return `${label}.${this.hostApexValue}`
  }
}
