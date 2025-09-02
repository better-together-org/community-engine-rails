// Helper function to map alert types to Bootstrap classes
function getAlertClass(type) {
  switch (type) {
    case 'notice':
    case 'success':
      return 'alert-success';
    case 'alert':
    case 'warning':
      return 'alert-warning';
    case 'error':
      return 'alert-danger';
    case 'info':
      return 'alert-info';
    default:
      return 'alert-secondary';
  }
}

// Function to display flash messages matching Rails template
function displayFlashMessage(type, message, onDismiss = null) {
  const flashContainer = document.querySelector('turbo-frame#flash_messages #col-flash-message');
  if (flashContainer) {
    const flashMessage = document.createElement('div');
    const alertClass = getAlertClass(type);

    flashMessage.className = `alert ${alertClass} alert-dismissible fade show text-center`;
    flashMessage.setAttribute('role', 'alert');
    flashMessage.setAttribute('data-better_together--flash-target', 'message');
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

    if (typeof onDismiss === "function") {
      // Set cookie on alert dismiss
      flashMessage.addEventListener('closed.bs.alert', onDismiss);
    }

    flashContainer.appendChild(flashMessage);

    // Auto-dismiss after 30 seconds
    setTimeout(() => {
      if (flashMessage.parentNode) {
        if (onDismiss) {
          flashMessage.removeEventListener('closed.bs.alert', onDismiss);
        }
        flashMessage.remove();
      }
    }, 10000);
  } else {
    console.warn('Flash messages container not found.');
  }
}

// Update badge, document title, and favicon with unread notification count
function updateUnreadNotifications(count) {
  // Update notification badge
  let badge = document.getElementById('person_notification_count');
  if (badge) {
    if (count > 0) {
      badge.textContent = count;
    } else {
      badge.remove();
      badge = null;
    }
  }
  if (!badge && count > 0) {
    const icon = document.getElementById('notification-icon');
    if (icon) {
      badge = document.createElement('span');
      badge.id = 'person_notification_count';
      badge.className = 'badge bg-primary rounded-pill position-absolute notification-badge';
      badge.textContent = count;
      icon.appendChild(badge);
    }
  }

  // Update document title
  const baseTitle = updateUnreadNotifications.baseTitle ||
    (updateUnreadNotifications.baseTitle = document.title.replace(/^\(\d+\)\s*/, ''));
  if (count > 0) {
    document.title = `(${count}) ${baseTitle}`;
  } else {
    document.title = baseTitle;
  }

  // Update favicon with red dot
  const link = document.querySelector("link[rel~='icon']");
  if (!link) return;
  if (!updateUnreadNotifications.originalHref) {
    updateUnreadNotifications.originalHref = link.href;
  }
  if (count > 0) {
    const img = document.createElement('img');
    img.src = updateUnreadNotifications.originalHref;
    img.onload = () => {
      const size = 32;
      const canvas = document.createElement('canvas');
      canvas.width = size;
      canvas.height = size;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, size, size);
      ctx.fillStyle = '#ff0000';
      ctx.beginPath();
      ctx.arc(size - 5, 5, 4, 0, 2 * Math.PI);
      ctx.fill();
      link.href = canvas.toDataURL('image/png');
    };
  } else {
    link.href = updateUnreadNotifications.originalHref;
  }
}

export {
  displayFlashMessage,
  updateUnreadNotifications
}

// Expose helpers globally for simple access in feature tests and inline usage
if (typeof window !== 'undefined') {
  window.BetterTogetherNotifications = { displayFlashMessage, updateUnreadNotifications }
  window.updateUnreadNotifications = updateUnreadNotifications
}
