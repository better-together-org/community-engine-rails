// app/javascript/controllers/better_together/map_controller.js
import { Controller } from "@hotwired/stimulus"
import L from 'leaflet'

export default class extends Controller {
  connect() {
    console.log('Map controller connected')
    this.initializeMap(48.952, -57.933)
  }

  initializeMap(latitude, longitude) {
    this.map = L.map(this.element).setView([latitude, longitude], 13);
    this.osmLayer = L.tileLayer.provider('OpenStreetMap.Mapnik').addTo(this.map);
    this.satelliteLayer = L.tileLayer.provider('Esri.WorldImagery');
  }

  switchToOSM() {
    this.map.removeLayer(this.satelliteLayer);
    this.osmLayer.addTo(this.map);
  }

  switchToSatellite() {
    this.map.removeLayer(this.osmLayer);
    this.satelliteLayer.addTo(this.map);
  }

  enableGeolocation() {
    const options = {
      enableHighAccuracy: true,
      timeout: 5000,
      maximumAge: 0,
    };

    const success = (pos) => {
      const crd = pos.coords;
      console.log("Your current position is:");
      console.log(`Latitude : ${crd.latitude}`);
      console.log(`Longitude: ${crd.longitude}`);
      console.log(`More or less ${crd.accuracy} meters.`);
      this.map.setView([crd.latitude, crd.longitude], 13);
    };

    const error = (err) => {
      console.warn(`ERROR(${err.code}): ${err.message}`);
      alert('Geolocation failed');
    };

    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition(success, error, options);
    } else {
      alert('Geolocation is not supported by this browser.');
    }
  }
}
