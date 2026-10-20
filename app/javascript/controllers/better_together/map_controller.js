// app/javascript/controllers/better_together/map_controller.js
import { Controller } from '@hotwired/stimulus'
import 'leaflet'
import 'leaflet-gesture-handling' // loaded for its side effect on L.Map (gestureHandling option)
import 'leaflet-providers'
import 'leaflet-extensible'
import 'leaflet.markercluster'

// Plugins attach to the extensible global set up by leaflet-extensible, so use it rather than the module namespace.
const L = window.L

// Geolocation: a quick coarse fix first (cached positions allowed), then one high accuracy attempt if that fails
// for a reason another attempt could fix. Permission denied is final. Browsers count the time spent waiting for the
// permission prompt towards the timeout, so the first attempt is generous.
const GEOLOCATION_ATTEMPTS = [
  { enableHighAccuracy: false, timeout: 15000, maximumAge: 300000 },
  { enableHighAccuracy: true, timeout: 30000, maximumAge: 0 }
]
const GEOLOCATION_ERROR_STATE = { 1: 'denied', 2: 'unavailable', 3: 'timeout' }

const DEFAULT_LABELS = {
  locating: 'Finding your location...',
  located: 'Showing your location.',
  denied: 'Location access is blocked. Allow it for this site in your browser settings and try again.',
  unavailable: 'Your location could not be determined. Check that location services are on and try again.',
  timeout: 'Finding your location took too long. Try again.',
  unsupported: 'Your browser does not support location.',
  youAreHere: 'You are here',
  showOnMap: 'Show on the map'
}

export default class extends Controller {
  static values = {
    center: String,
    spaces: Array,
    zoom: Number,
    extent: String,
    enablePopups: { type: Boolean, default: true }, // Default to enabling popups
    useLabelAsPopup: { type: Boolean, default: false }, // Default to using popup_html
    cluster: { type: Boolean, default: true }, // Group nearby points by density
    types: Array, // [{ key, label, color }] for points that carry a type; drives the legend
    boundary: Object, // GeoJSON drawn as an outline layer
    boundaryAttribution: String, // credit for the boundary data, shown in the attribution control with the layer
    layers: Array, // [{ key, label, style, geojson | url, attribution }] data layers credited while on the map
    labels: Object // translated strings, see DEFAULT_LABELS
  }

  connect() {
    const center = this.centerValue.split(',').map(Number)
    const zoom = this.zoomValue
    const extent = this.extentValue ? JSON.parse(this.extentValue) : null

    this.markers = []
    this.geolocationState = 'idle'
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

    this.addBoundary()
    this.addDataLayers()
    this.addPointsWithLabels(this.spacesValue)
    this.addLegend()
    this.addStatusRegion()

    this.map.on('click', (e) => {
      if (e.originalEvent.target.closest('.map-controls')) {
        return // Ignore clicks on elements inside .map-controls
      }
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

  // ---- Geolocation -------------------------------------------------------------------------------------------

  enableGeolocation(event) {
    if (event && event.preventDefault) event.preventDefault()
    if (this.geolocationState === 'locating') return

    if (!navigator.geolocation) {
      this.setGeolocationState('unsupported')
      return
    }

    this.setGeolocationState('locating')
    this.requestPosition(0)
  }

  requestPosition(attempt) {
    navigator.geolocation.getCurrentPosition(
      (position) => this.handlePosition(position),
      (error) => this.handlePositionError(error, attempt),
      GEOLOCATION_ATTEMPTS[attempt]
    )
  }

  handlePosition(position) {
    const { latitude, longitude, accuracy } = position.coords
    const latlng = [latitude, longitude]

    this.showCurrentPosition(latlng, accuracy)
    this.map.setView(latlng, 13)
    this.setGeolocationState('located')
    this.element.dispatchEvent(new CustomEvent('map:located', { detail: { latlng, accuracy } }))
  }

  handlePositionError(error, attempt) {
    const state = GEOLOCATION_ERROR_STATE[error && error.code] || 'unavailable'
    const retryable = state !== 'denied' && attempt + 1 < GEOLOCATION_ATTEMPTS.length

    if (retryable) {
      this.requestPosition(attempt + 1)
      return
    }

    this.setGeolocationState(state)
    this.element.dispatchEvent(new CustomEvent('map:locationerror', { detail: { state, code: error && error.code } }))
  }

  setGeolocationState(state) {
    this.geolocationState = state
    this.element.dataset.geolocationState = state

    const button = this.element.querySelector('[data-geolocation-button]')
    if (button) button.setAttribute('aria-busy', String(state === 'locating'))

    if (this.statusElement) this.statusElement.textContent = this.label(state === 'idle' ? '' : state)
  }

  showCurrentPosition(latlng, accuracy) {
    if (this.positionLayer) this.map.removeLayer(this.positionLayer)

    const dot = L.circleMarker(latlng, { radius: 7, color: '#ffffff', weight: 2, fillColor: '#0d6efd', fillOpacity: 1 })
    dot.bindTooltip(this.label('youAreHere'))
    const parts = [dot]
    if (accuracy) parts.unshift(L.circle(latlng, { radius: accuracy, color: '#0d6efd', weight: 1, fillOpacity: 0.1 }))
    this.positionLayer = L.layerGroup(parts).addTo(this.map)
  }

  addStatusRegion() {
    this.statusElement = document.createElement('div')
    this.statusElement.className = 'map-status visually-hidden'
    this.statusElement.setAttribute('role', 'status')
    this.statusElement.setAttribute('aria-live', 'polite')
    this.element.appendChild(this.statusElement)
  }

  label(key) {
    if (!key) return ''
    return (this.hasLabelsValue && this.labelsValue[key]) || DEFAULT_LABELS[key] || ''
  }

  // ---- Points, clustering, types, boundary -------------------------------------------------------------------

  addBoundary() {
    if (!this.hasBoundaryValue || !this.boundaryValue.type) return

    this.boundaryLayer = L.geoJSON(this.boundaryValue, {
      style: { color: '#0d6efd', weight: 2, fillOpacity: 0.08 },
      interactive: false,
      attribution: this.hasBoundaryAttributionValue ? this.boundaryAttributionValue : undefined
    }).addTo(this.map)
  }

  // Each layer carries its own attribution, so Leaflet credits the source exactly while the layer is on the map.
  // Layers with a url are fetched when the map connects, so pages do not embed the data.
  addDataLayers() {
    this.dataLayers = this.layersValue.map((layer) => {
      const geoLayer = L.geoJSON(layer.geojson || null, {
        style: layer.style,
        interactive: false,
        attribution: layer.attribution
      }).addTo(this.map)
      if (layer.url) this.loadLayerData(geoLayer, layer.url)
      return geoLayer
    })
  }

  loadLayerData(geoLayer, url) {
    fetch(url, { headers: { Accept: 'application/geo+json, application/json' } })
      .then((response) => (response.ok ? response.json() : Promise.reject(new Error(response.status))))
      .then((data) => geoLayer.addData(data))
      .catch(() => this.element.dispatchEvent(new CustomEvent('map:layererror', { bubbles: true, detail: { url } })))
  }

  // Subclasses can replace the layer markers are added to.
  createMarkerLayer() {
    if (this.clusterValue && typeof L.markerClusterGroup === 'function') {
      return L.markerClusterGroup({
        iconCreateFunction: (cluster) => this.clusterIcon(cluster),
        maxClusterRadius: 50,
        showCoverageOnHover: false
      })
    }

    return L.layerGroup()
  }

  // A point may carry type, color and icon (a Font Awesome class); without them it is the default Leaflet pin.
  buildMarker(point) {
    const { lat, lng, label, popup_html, type, color, icon } = point
    const options = {}
    if (color || icon) {
      options.icon = L.divIcon({
        className: 'map-pin',
        html: `<span style="background:${color || '#6c757d'}"><i class="fas ${icon || 'fa-location-dot'}" aria-hidden="true"></i></span>`,
        iconSize: [30, 30],
        iconAnchor: [15, 15]
      })
    }

    const marker = L.marker([lat, lng], options)
    marker.pointType = type

    const popupContent = this.useLabelAsPopupValue ? label : popup_html
    if (popupContent) marker.bindPopup(popupContent)
    return marker
  }

  clusterIcon(cluster) {
    const count = cluster.getChildCount()
    const size = count < 10 ? 'small' : count < 100 ? 'medium' : 'large'
    const typeColors = this.typeColors()

    const counts = {}
    cluster.getAllChildMarkers().forEach((marker) => {
      if (marker.pointType) counts[marker.pointType] = (counts[marker.pointType] || 0) + 1
    })

    let background = ''
    if (Object.keys(counts).length > 0) {
      let at = 0
      const stops = Object.entries(counts).map(([type, n]) => {
        const from = at
        at += (n / count) * 100
        return `${typeColors[type] || '#6c757d'} ${from}% ${at}%`
      })
      background = ` style="background:conic-gradient(${stops.join(',')})"`
    }

    return L.divIcon({
      className: `map-cluster map-cluster-${size}`,
      html: `<span${background}><b>${count}</b></span>`,
      iconSize: [40, 40]
    })
  }

  typeColors() {
    return Object.fromEntries(this.typesValue.map((type) => [type.key, type.color]))
  }

  addPointsWithLabels(points) {
    if (!Array.isArray(points) || points.length === 0) {
      return
    }

    this.markerLayer = this.createMarkerLayer()
    this.markers = points.map((point) => this.buildMarker(point))
    this.markerLayer.addLayers ? this.markerLayer.addLayers(this.markers) : this.markers.forEach((m) => this.markerLayer.addLayer(m))
    this.markerLayer.addTo(this.map)

    if (points.length === 1) {
      const singlePoint = points[0]
      this.map.setView([singlePoint.lat, singlePoint.lng], this.zoomValue) // Adjust zoom level for a single point
      const popupContent = this.useLabelAsPopupValue ? singlePoint.label : singlePoint.popup_html
      if (this.enablePopupsValue && popupContent) this.markers[0].openPopup() // Automatically open the popup
    } else {
      const bounds = L.latLngBounds(points.map((point) => [point.lat, point.lng]))
      if (this.boundaryLayer) bounds.extend(this.boundaryLayer.getBounds())
      this.map.fitBounds(bounds, { padding: [50, 50] }) // Add padding to ensure points are visible
    }
  }

  // A legend (one checkbox per point type) when points carry types.
  addLegend() {
    const present = new Set(this.markers.map((marker) => marker.pointType).filter(Boolean))
    const types = this.typesValue.filter((type) => present.has(type.key))
    if (types.length === 0) return

    const control = L.control({ position: 'bottomleft' })
    control.onAdd = () => {
      const container = L.DomUtil.create('fieldset', 'map-legend leaflet-bar')
      const legend = L.DomUtil.create('legend', 'visually-hidden', container)
      legend.textContent = this.label('showOnMap')
      types.forEach((type) => {
        const row = L.DomUtil.create('label', 'map-legend-row', container)
        const input = L.DomUtil.create('input', 'form-check-input', row)
        input.type = 'checkbox'
        input.checked = true
        input.value = type.key
        input.addEventListener('change', () => this.toggleType(type.key, input.checked))
        const swatch = L.DomUtil.create('span', 'map-legend-swatch', row)
        swatch.style.background = type.color
        row.appendChild(document.createTextNode(` ${type.label}`))
      })
      L.DomEvent.disableClickPropagation(container)
      return container
    }
    control.addTo(this.map)
  }

  toggleType(type, visible) {
    const layers = this.markers.filter((marker) => marker.pointType === type)
    if (visible) {
      this.markerLayer.addLayers ? this.markerLayer.addLayers(layers) : layers.forEach((m) => this.markerLayer.addLayer(m))
    } else {
      this.markerLayer.removeLayers ? this.markerLayer.removeLayers(layers) : layers.forEach((m) => this.markerLayer.removeLayer(m))
    }
  }
}
