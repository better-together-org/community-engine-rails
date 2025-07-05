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
    flashMessage.innerHTML = `
      <strong>Notification Permission Required</strong>: Please enable notifications to stay updated.
      <button type="button" class="btn btn-primary ms-2" id="request-notification-permission">Enable Notifications</button>
      <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    `;
    flashContainer.appendChild(flashMessage);

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
      const expires = new Date(Date.now() + 3 * 60 * 1000).toUTCString();
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

    console.log(Notification.permission, data);

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
