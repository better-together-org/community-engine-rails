function initializeDropdowns() {
  var dropdownTriggerList = [].slice.call(
    document.querySelectorAll('[data-bs-toggle="dropdown"]')
  );
  dropdownTriggerList.forEach(function (dropdownTriggerEl) {
    // Check if a Bootstrap Dropdown instance already exists
    if (!bootstrap.Dropdown.getInstance(dropdownTriggerEl)) {
      var dropdown = new bootstrap.Dropdown(dropdownTriggerEl);
      // dropdownTriggerEl.addEventListener('click', function (e) {
      //   e.preventDefault();
      //   dropdown.toggle();
      // });
    }
  });
}

// Run dropdown initialization on DOMContentLoaded
// document.addEventListener('DOMContentLoaded', initializeDropdowns);

// Run dropdown initialization on Turbo load events
document.addEventListener('turbo:load', initializeDropdowns);
