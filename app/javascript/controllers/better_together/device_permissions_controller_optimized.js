// Alternative implementation using data attributes instead of global I18n
// This version of device_permissions_controller.js uses data-i18n-* attributes
// to get translations instead of loading the entire translation dataset

import { Controller } from "@hotwired/stimulus"
import PermissionManager from "better_together/permission_manager"

export default class extends Controller {
  static targets = ["geolocationStatus", "notificationsStatus", "cameraStatus", "microphoneStatus"]
  static values = { 
    geolocationMessage: String,
    notificationsMessage: String,
    cameraMessage: String,
    microphoneMessage: String
  }

  static permissionMap = {
    "geolocation": "geolocation",
    "notifications": "notifications",
    "camera": "camera",
    "microphone": "microphone"
  }

  connect() {
    this.updatePermissionStatuses();
    
    // Cache translations from data attributes for performance
    this.translations = {
      status: {
        granted: this.getTranslation(0, "Granted"),
        denied: this.getTranslation(1, "Denied"), 
        unknown: this.getTranslation(2, "Unknown")
      },
      location: {
        denied: this.getTranslation(3, "Location permission was denied."),
        enabled: this.getTranslation(4, "Location access granted."),
        unsupported: this.getTranslation(5, "Geolocation is not supported by your browser.")
      }
    };
  }

  getTranslation(index, fallback = '') {
    return this.element.dataset[`i18n${index}`] || fallback;
  }

  // Rest of the controller methods remain the same, but replace I18n.t() calls
  // with this.translations.path.to.key
  
  setPermissionStatus(status, statusElement) {
    let iconHtml, label;
    if (status === "granted") {
      iconHtml = '<i class="fa-solid fa-check text-success" aria-hidden="true"></i>';
      label = this.translations.status.granted;
    } else if (status === "denied") {
      iconHtml = '<i class="fa-solid fa-xmark text-danger" aria-hidden="true"></i>';
      label = this.translations.status.denied;
    } else {
      iconHtml = '<i class="fa-solid fa-question text-secondary" aria-hidden="true"></i>';
      label = this.translations.status.unknown;
    }

    statusElement.innerHTML = `${iconHtml} <span class="visually-hidden">${label}</span>`;
  }

  handleGeolocationPermission(button) {
    this.checkPermission(
      "geolocation",
      () => {
        displayFlashMessage("success", this.translations.location.enabled);
      },
      () => {
        displayFlashMessage("warning", this.translations.location.denied);
      },
      () => {
        if (navigator.geolocation) {
          navigator.geolocation.getCurrentPosition(
            (position) => {
              this.updatePermissionStatus("geolocation", this.geolocationStatusTarget);
              displayFlashMessage("success", "Geolocation has been enabled.");
            },
            (error) => {
              this.updatePermissionStatus("geolocation", this.geolocationStatusTarget);
              displayFlashMessage("warning", "Geolocation has been enabled, but there is a problem retreiving your location.");
            }
          );
        } else {
          displayFlashMessage("danger", this.translations.location.unsupported);
        }
      }
    );

    button.closest(".alert").remove();
  }

  // ... other methods remain largely the same
}
