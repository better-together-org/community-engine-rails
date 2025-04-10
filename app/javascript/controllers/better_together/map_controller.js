// app/javascript/controllers/better_together/map_controller.js
import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

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

  initializeMap(center, zoom, extent) {
    this.map = L.map(this.element).setView(center, zoom)
    this.osmLayer = L.tileLayer.provider('OpenStreetMap.Mapnik').addTo(this.map)
    this.satelliteLayer = L.tileLayer.provider('Esri.WorldImagery')

    if (extent) {
      const bounds = L.latLngBounds(extent)
      this.map.fitBounds(bounds)
    }

    this.addPointsWithLabels(this.spacesValue)
    // this.map.on('click', (e) => {
    //   console.log(`Map clicked at: ${e.latlng}`)
    // })
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
      console.log("Your current position is:")
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

      if (this.enablePopupsValue) {
        const popupContent = this.useLabelAsPopupValue ? label : popup_html
        if (popupContent) {
          marker.bindPopup(popupContent).openPopup() // Automatically open the popup
        }
      }

      return marker
    })

    const currentZoom = this.map.getZoom()
    const bounds = L.latLngBounds(points.map(point => [point.lat, point.lng]))
    this.map.fitBounds(bounds)
    const newZoom = this.map.getZoom()
    const halfwayZoom = (currentZoom + newZoom) / 2
    this.map.setZoom(halfwayZoom)
  }
}
