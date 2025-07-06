import consumer from 'channels/consumer';

// Function to display flash messages matching Rails template
function displayFlashMessage(type, message) {
  const flashContainer = document.querySelector('turbo-frame#flash_messages');
  if (flashContainer) {
    const flashMessage = document.createElement('div');
    flashMessage.className = `alert ${type === 'notice' ? 'alert-success' : ''} ${type === 'alert' ? 'alert-warning' : ''} ${type === 'error' ? 'alert-danger' : ''} ${type === 'info' ? 'alert-info' : ''} alert-dismissible fade show text-center`;
    flashMessage.setAttribute('role', 'alert');
    flashMessage.innerHTML = `
      <span class="me-2"><i class="fa-solid fa-envelope"></i></span>
      ${message}
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `;

    // If there are more than 3 alerts, remove the first one
    const alerts = flashContainer.querySelectorAll('.alert');
    if (alerts.length >= 3) {
      alerts[0].remove();
    }

    flashContainer.appendChild(flashMessage);

    // Auto-dismiss after 30 seconds
    setTimeout(() => {
      if (flashMessage.parentNode) {
      flashMessage.remove();
      }
    }, 15000);
  } else {
    console.warn('Flash messages container not found.');
  }
}

// Function to display notification permission prompt
/**
 * Displays a permission prompt for enabling browser notifications in a flash message container.
 * The prompt is only shown if it hasn't been dismissed recently (within the last 7 days).
 * When the user dismisses the prompt, a cookie is set to prevent re-showing the prompt for 7 days.
 * The prompt includes buttons to request notification permission or to close the alert.
 *
 * Human-relevant units:
 * - The dismissal cookie lasts for 7 days.
 *
 * @function
 */
function displayPermissionPrompt() {
  const flashContainer = document.querySelector('turbo-frame#flash_messages');
  if (flashContainer) {
    // Check if the prompt was recently dismissed
    if (document.cookie.includes('notification_permission_prompt_dismissed=true')) {
      return;
    }

    const flashMessage = document.createElement('div');
    flashMessage.className = 'alert alert-info alert-dismissible fade show text-center';
    flashMessage.setAttribute('role', 'alert');
    // Strings for translation/localization
    const notificationPermissionTitle = "Enable Notifications";
    const notificationPermissionMessage = "To stay updated, please allow browser notifications.";
    const enableButtonLabel = "Enable";
    const closeButtonLabel = "Close";
    // Expiry time for the dismissal cookie: 7 days in milliseconds
    const expiryTimeMs = 7 * 24 * 60 * 60 * 1000;

    flashMessage.innerHTML = `
      <strong>${notificationPermissionTitle}</strong>: ${notificationPermissionMessage}
      <button type="button" class="btn btn-primary ms-2" id="request-notification-permission">${enableButtonLabel}</button>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="${closeButtonLabel}"></button>
    `;
    // Only append the prompt if one is not already present
    if (!flashContainer.querySelector('.notification-permission-prompt')) {
      flashMessage.classList.add('notification-permission-prompt');
      flashContainer.appendChild(flashMessage);

      // Auto-dismiss after 30 seconds
      setTimeout(() => {
        if (flashMessage.parentNode) {
          flashMessage.remove();
        }
      }, 60000);
    }

    const button = document.getElementById('request-notification-permission');
    button.onclick = () => {
      Notification.requestPermission().then(permission => {
      console.log(`Notification permission: ${permission}`);
      flashMessage.remove();
      });
    };

    // Set cookie on alert dismiss
    const closeBtn = flashMessage.querySelector('.btn-close');
    closeBtn.addEventListener('click', () => {
      const expires = new Date(Date.now() + expiryTimeMs).toUTCString();
      document.cookie = `notification_permission_prompt_dismissed=true; expires=${expires}; path=/`;
    });
  } else {
    console.warn('Flash messages container not found.');
  }
}

consumer.subscriptions.create("BetterTogether::NotificationsChannel", {
  connected() {
    console.log("notifications channel connected");
  },
  received(data) {
    const identifier = data["identifier"];
    // Only proceed if identifier exists and current location does not contain it
    if (!identifier || window.location.href.includes(identifier)) {
      return;
    }

    // Only display the flash message and permission request if the permission is not already granted
    function showInfoFlashMessage(data) {
      let messageContent = `${data["title"]} - ${data["body"]}`;
      if (data["url"]) {
        messageContent = `<a href="${data["url"]}" target="_blank" rel="noopener" style="color:inherit;">${messageContent}</a>`;
      }
      displayFlashMessage(
        "info",
        messageContent
      );
    }

    if (Notification.permission === "default") {
      showInfoFlashMessage(data);
      displayPermissionPrompt();
      return;
    }

    // If permission is granted, display the notification
    if (Notification.permission === "granted") {
      showInfoFlashMessage(data);
      const notification = new Notification(data["title"], { body: data["body"] });
      if (data["url"]) {
        notification.onclick = function(event) {
          event.preventDefault();
          window.open(data["url"], (identifier || '_blank'));
        };
      }
    }
  }
});
