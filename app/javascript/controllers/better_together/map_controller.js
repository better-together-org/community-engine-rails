// Polyfill for `global` to fix compatibility issues with leaflet-gesture-handling

// app/javascript/controllers/better_together/map_controller.js
import { Controller } from '@hotwired/stimulus'
import L from 'leaflet'
import 'leaflet-gesture-handling' // Import the library to ensure it is loaded globally

export default class extends Controller {
  static values = {
    center: String,
    spaces: Array,
    zoom: Number,
    extent: String,
    enablePopups: { type: Boolean, default: true }, // Default to enabling popups
    useLabelAsPopup: { type: Boolean, default: false } // Default to using popup_html
  }

  connect() {
    console.log('Map controller connected')
    const center = this.centerValue.split(',').map(Number)
    const zoom = this.zoomValue
    const extent = this.extentValue ? JSON.parse(this.extentValue) : null

    this.initializeMap(center, zoom, extent)
  }

  disconnect() {
    this.map.remove()
  }

  initializeMap(center, zoom, extent) {
    this.map = L.map(this.element, {
      gestureHandling: true // Enable gesture handling
    }).setView(center, zoom)

    this.osmLayer = L.tileLayer.provider('OpenStreetMap.Mapnik').addTo(this.map)
    this.satelliteLayer = L.tileLayer.provider('Esri.WorldImagery')

    if (extent) {
      const bounds = L.latLngBounds(extent)
      this.map.fitBounds(bounds)
    }

    this.addPointsWithLabels(this.spacesValue)

    this.map.on('click', (e) => {
      if (e.originalEvent.target.closest('.map-controls')) {
        return // Ignore clicks on elements inside .map-controls
      }
      console.log(`Map clicked at: ${e.latlng}`)
      const event = new CustomEvent('map:clicked', {
      detail: { latlng: e.latlng }
      })
      this.element.dispatchEvent(event)
    })

    // Listen for marker:add event
    this.element.addEventListener('marker:add', (event) => {
      const { id, latlng } = event.detail
      const marker = L.marker(latlng).addTo(this.map)
      this.map.setView(latlng, this.map.getZoom()) // Set the map center to the new point
      marker.id = id

      // Enable dragging and emit marker:moved event on drag end
      marker.on('dragend', (e) => {
        const { lat, lng } = e.target.getLatLng()
        this.element.dispatchEvent(new CustomEvent('marker:moved', {
          detail: { id, lat, lng }
        }))
      })

      marker.dragging.enable()
      this.map._markers = this.map._markers || {}
      this.map._markers[id] = marker
    })

    // Listen for marker:remove event
    this.element.addEventListener('marker:remove', (event) => {
      const { id } = event.detail
      if (this.map._markers && this.map._markers[id]) {
        this.map.removeLayer(this.map._markers[id])
        delete this.map._markers[id]
      }
    })

    // Emit map:ready event
    const readyEvent = new CustomEvent('map:ready', {
      detail: { map: this.map }
    })
    this.element.dispatchEvent(readyEvent)
  }

  switchToOSM() {
    this.map.removeLayer(this.satelliteLayer)
    this.osmLayer.addTo(this.map)
  }

  switchToSatellite() {
    this.map.removeLayer(this.osmLayer)
    this.satelliteLayer.addTo(this.map)
  }

  enableGeolocation() {
    const options = {
      enableHighAccuracy: true,
      timeout: 5000,
      maximumAge: 0,
    }

    const success = (pos) => {
      const crd = pos.coords
      console.log('Your current position is:')
      console.log(`Latitude : ${crd.latitude}`)
      console.log(`Longitude: ${crd.longitude}`)
      console.log(`More or less ${crd.accuracy} meters.`)
      this.map.setView([crd.latitude, crd.longitude], 13)
    }

    const error = (err) => {
      console.warn(`ERROR(${err.code}): ${err.message}`)
      alert('Geolocation failed')
    }

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(success, error, options)
    } else {
      alert('Geolocation is not supported by this browser.')
    }
  }

  addPointsWithLabels(points) {
    if (!Array.isArray(points) || points.length === 0) {
      console.warn('No points provided or invalid format')
      return
    }

    const markers = points.map(point => {
      const { lat, lng, label, popup_html } = point
      const marker = L.marker([lat, lng]).addTo(this.map)

      const popupContent = this.useLabelAsPopupValue ? label : popup_html
      const popup = marker.bindPopup(popupContent)

      if (points.length === 1 && this.enablePopupsValue && popupContent) {
        popup.openPopup() // Automatically open the popup
      }

      return marker
    })

    if (points.length === 1) {
      const singlePoint = points[0]
      this.map.setView([singlePoint.lat, singlePoint.lng], this.zoomValue) // Adjust zoom level for a single point
    } else {
      const bounds = L.latLngBounds(points.map(point => [point.lat, point.lng]))
      this.map.fitBounds(bounds, { padding: [50, 50] }) // Add padding to ensure points are visible
    }
  }
}
