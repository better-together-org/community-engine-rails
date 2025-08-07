import { Controller } from "@hotwired/stimulus";
import PermissionManager from "better_together/permission_manager";
import { displayFlashMessage } from "better_together/notifications";

export default class extends Controller {
  static targets = [
    "geolocationButton",
    "notificationsButton",
    "cameraButton",
    "microphoneButton",
    "geolocationStatus",
    "notificationsStatus",
    "cameraStatus",
    "microphoneStatus",
  ];

  static permissionMap = {
    geolocation: "geolocation",
    notifications: "notifications",
    camera: "camera",
    microphone: "microphone",
  };

  connect() {
    // console.log("Device Permissions Controller connected");
    this.updatePermissionStatuses();
  }

  requestGeolocation(event) {
    event.preventDefault();
    this.checkPermission(
      "geolocation",
      () => {
        displayFlashMessage("info", "Geolocation is already enabled.");
      },
      () => {
        displayFlashMessage(
          "warning",
          "Geolocation is disabled."
        );
      },
      () => {
        this.displayPermissionPrompt("geolocation", "Allow access to your location to enhance your experience.", event);
      }
    );
  }

  requestNotifications(event) {
    event.preventDefault();
    this.checkPermission(
      "notifications",
      () => {
        displayFlashMessage("info", "Notifications are already enabled.");
      },
      () => {
        displayFlashMessage(
          "warning",
          I18n.t("better_together.device_permissions.location.denied", {
            defaultValue: "Location permission was denied."
          })
        );
      },
      () => {
        this.displayPermissionPrompt("notifications", "Enable notifications to stay updated.", event);
      }
    );
  }

  requestCamera(event) {
    event.preventDefault();
    this.displayPermissionPrompt("camera", "Allow access to your camera for video features.", event);
  }

  requestMicrophone(event) {
    event.preventDefault();
    this.displayPermissionPrompt("microphone", "Allow access to your microphone for audio features.", event);
  }

  displayPermissionPrompt(permissionType, message, event = null) {
    const checkCookie = typeof(event) === null
    const cookieValue = `${permissionType}_permission_prompt_dismissed=true`

    if (checkCookie && document.cookie.includes(cookieValue)) {
      return;
    }

    const permissionTitle = `Enable ${permissionType.charAt(0).toUpperCase() + permissionType.slice(1)} Permission`;
    const enableButtonLabel = "Enable";
    const closeButtonLabel = "Close";
    const expiryTimeMs = 7 * 24 * 60 * 60 * 1000;

    const flashMessage = `
      <strong>${permissionTitle}</strong>: ${message}
      <button type="button" class="btn btn-primary ms-2" id="request-${permissionType}-permission">${enableButtonLabel}</button>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="${closeButtonLabel}"></button>
    `;

    displayFlashMessage("info", flashMessage, (event) => {
      event.preventDefault();
      event.stopPropagation();
      const expires = new Date(Date.now() + expiryTimeMs).toUTCString();
      document.cookie = `${cookieValue}; expires=${expires}; path=/`;

    });

    const button = document.getElementById(`request-${permissionType}-permission`);
    if (button) {
      button.onclick = () => {
        const methodName = `handle${permissionType[0].toUpperCase()}${permissionType.slice(1)}Permission`;
        if (typeof this[methodName] === "function") {
          this[methodName](button);
        } else {
          button.closest(".alert").remove();
        }
      };
    }
  }

  updatePermissionStatuses() {
    this.updatePermissionStatus("geolocation", this.geolocationStatusTarget);
    this.updatePermissionStatus("notifications", this.notificationsStatusTarget);
    this.updatePermissionStatus("camera", this.cameraStatusTarget);
    this.updatePermissionStatus("microphone", this.microphoneStatusTarget);
  }

  updatePermissionStatus(permissionType, statusElement) {
    const navigatorPermissionName = this.constructor.permissionMap[permissionType];

    if (!navigatorPermissionName) {
      console.warn(`Permission type '${permissionType}' is not supported.`);
      this.setPermissionStatus("unknown", statusElement);
      return;
    }

    if ("permissions" in navigator) {
      PermissionManager.queryPermission(navigatorPermissionName)
        .then((permissionStatus) => {
          // console.log(`${navigatorPermissionName} permission status is ${permissionStatus.state}`);
          this.setPermissionStatus(permissionStatus.state, statusElement);

          permissionStatus.onchange = () => {
            // console.log(
            //   `${navigatorPermissionName} permission status has changed to ${permissionStatus.state}`
            // );
            this.setPermissionStatus(permissionStatus.state, statusElement);
          };
        })
        .catch((error) => {
          console.error(`Error querying ${navigatorPermissionName} permission:`, error);
          this.setPermissionStatus("unknown", statusElement);
        });
    } else {
      this.setPermissionStatus("unknown", statusElement);
    }
  }

  setPermissionStatus(status, statusElement) {
    let iconHtml, label;
    if (status === "granted") {
      iconHtml = '<i class="fa-solid fa-check text-success" aria-hidden="true"></i>';
      label = I18n.t("better_together.device_permissions.status.granted", { defaultValue: "Granted" });
    } else if (status === "denied") {
      iconHtml = '<i class="fa-solid fa-xmark text-danger" aria-hidden="true"></i>';
      label = I18n.t("better_together.device_permissions.status.denied", { defaultValue: "Denied" });
    } else {
      iconHtml = '<i class="fa-solid fa-question text-secondary" aria-hidden="true"></i>';
      label = I18n.t("better_together.device_permissions.status.unknown", { defaultValue: "Unknown" });
    }

    statusElement.innerHTML = `${iconHtml} <span class="visually-hidden">${label}</span>`;
  }

  checkPermission(permissionName, onGranted, onDenied = null, onOther = null) {
    if ("permissions" in navigator) {
      PermissionManager.queryPermission(permissionName)
        .then((permissionStatus) => {
          if (permissionStatus.state === "granted") {
            onGranted();
          } else if (permissionStatus.state === "denied" && onDenied) {
            onDenied();
          } else if (onOther) {
            onOther();
          }
        })
        .catch((error) => {
          console.error(`Error querying ${permissionName} permission:`, error);
        });
    } else {
      console.warn(`Permissions API is not supported in this browser.`);
    }
  }

  handleGeolocationPermission(button) {
    this.checkPermission(
      "geolocation",
      () => {
        displayFlashMessage(
          "success",
          I18n.t("better_together.device_permissions.location.enabled", {
            defaultValue: "Location access granted."
          })
        );
      },
      () => {
        displayFlashMessage(
          "warning",
          I18n.t("better_together.device_permissions.location.denied", {
            defaultValue: "Location permission was denied."
          })
        );
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
          displayFlashMessage(
            "danger",
            I18n.t("better_together.device_permissions.location.unsupported", {
              defaultValue: "Geolocation is not supported by your browser."
            })
          );
        }
      }
    );

    button.closest(".alert").remove();
  }

  handleNotificationsPermission(button) {
    // console.log("Handling notifications permission request");

    Notification.requestPermission().then((permission) => {
      // console.log(`Notifications permission: ${permission}`);
      this.updatePermissionStatus("notifications", this.notificationsStatusTarget);
      if (permission === "granted") {
        displayFlashMessage("success", "Notifications have been enabled.");
      } else {
        displayFlashMessage("warning", "Notifications permission was not granted.");
      }
      button.closest(".alert").remove();
    });
  }

  handleCameraPermission(button) {
    // console.log("Handling camera permission request");
    // Add logic to handle camera permission here
    this.updatePermissionStatus("camera", this.cameraStatusTarget);
    button.closest(".alert").remove();
  }

  handleMicrophonePermission(button) {
    // console.log("Handling microphone permission request");
    // Add logic to handle microphone permission here
    this.updatePermissionStatus("microphone", this.microphoneStatusTarget);
    button.closest(".alert").remove();
  }
}