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

export {
  displayFlashMessage
}
