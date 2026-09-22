// Stimulus controller for StorageConfiguration form.
// Shows/hides S3-specific fields based on the selected service_type.

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["s3Fields", "regionField", "endpointField"]

  connect() {
    this.toggleS3Fields()
  }

  toggleS3Fields() {
    const select = this.element.querySelector('[name*="service_type"]')
    if (!select) return

    const isLocal = select.value === 'local'
    const isAmazon = select.value === 'amazon'
    const isS3Compatible = select.value === 's3_compatible'

    if (this.hasS3FieldsTarget) {
      this.s3FieldsTarget.classList.toggle('d-none', isLocal)
    }

    // Region is required for Amazon S3 but optional for s3_compatible (Garage auto-detects)
    if (this.hasRegionFieldTarget) {
      const regionInput = this.regionFieldTarget.querySelector('input')
      if (regionInput) regionInput.required = isAmazon
    }

    // Endpoint is required for s3_compatible but not used for Amazon S3
    if (this.hasEndpointFieldTarget) {
      const endpointInput = this.endpointFieldTarget.querySelector('input')
      if (endpointInput) endpointInput.required = isS3Compatible
    }
  }
}
