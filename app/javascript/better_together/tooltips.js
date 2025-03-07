function initializeTooltips() {
  var tooltipTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="tooltip"]')
  );
  tooltipTriggerList.map(function (tooltipTriggerEl) {
    return new bootstrap.Tooltip(tooltipTriggerEl);
  });
}

// Run tooltip initialization on DOMContentLoaded
document.addEventListener('DOMContentLoaded', initializeTooltips);

// Run tooltip initialization on Turbo load events
document.addEventListener('turbo:load', initializeTooltips);
