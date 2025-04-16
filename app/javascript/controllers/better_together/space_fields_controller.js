import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['latitude', 'longitude', 'map']

  connect() {
    console.log('SpaceFieldController connected')

    // Listen for map click events to set latitude and longitude
    this.mapTarget.addEventListener('map:clicked', (event) => {
      this.handleMapClick(event.detail)
    })

    // Initialize marker if latitude and longitude are already set
    const lat = parseFloat(this.latitudeTarget.value)
    const lng = parseFloat(this.longitudeTarget.value)
    if (!isNaN(lat) && !isNaN(lng)) {
      this.mapTarget.addEventListener('map:ready', () => {
        this.updateMarker([lat, lng])
      }, { once: true })
    }
  }

  handleMapClick(event) {
    const { lat, lng } = event.latlng

    const markerClicked = event.originalEvent ? event.originalEvent.target.classList.contains('leaflet-marker-icon') : false

    if (!markerClicked) {
      if (confirm(`Set latitude to ${lat.toFixed(6)} and longitude to ${lng.toFixed(6)}?`)) {
      this.latitudeTarget.value = lat.toFixed(6)
      this.longitudeTarget.value = lng.toFixed(6)
      this.updateMarker([lat, lng])
      }
    }
  }

  updateMarker(latlng) {
    const markerId = `marker-${latlng[0].toFixed(6)}-${latlng[1].toFixed(6)}`

    if (this.marker) {
      this.mapTarget.dispatchEvent(new CustomEvent('marker:remove', {
      detail: { id: this.marker.id }
      }))
    }

    this.marker = { id: markerId, latlng }
    this.mapTarget.dispatchEvent(new CustomEvent('marker:add', {
      detail: { id: markerId, latlng }
    }))

    this.mapTarget.addEventListener('marker:moved', (event) => {
      if (event.detail.id === markerId) {
      const { lat, lng } = event.detail
      this.latitudeTarget.value = lat.toFixed(6)
      this.longitudeTarget.value = lng.toFixed(6)
      }
    })
  }

  latitudeTargetChanged() {
    this.syncMarkerWithFields()
  }

  longitudeTargetChanged() {
    this.syncMarkerWithFields()
  }

  syncMarkerWithFields() {
    const lat = parseFloat(this.latitudeTarget.value)
    const lng = parseFloat(this.longitudeTarget.value)

    if (!isNaN(lat) && !isNaN(lng)) {
      this.updateMarker([lat, lng])
    }
  }
}
