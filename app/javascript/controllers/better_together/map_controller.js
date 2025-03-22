// app/javascript/controllers/better_together/map_controller.js
import { Controller } from "@hotwired/stimulus"
// import L from 'leaflet'

console.log('test')

export default class extends Controller {
  connect() {
    console.log('Map controller connected')
    // this.map = L.map(this.element).setView([51.505, -0.09], 13)
    // L.tileLayer.provider('OpenStreetMap.Mapnik').addTo(this.map)
  }
}
