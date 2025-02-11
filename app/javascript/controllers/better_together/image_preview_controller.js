import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview", "deleteField", "deleteButton"]

  connect() {
    if (this.previewTarget.dataset.imageClasses) {
      this.imageClasses = this.previewTarget.dataset.imageClasses;
    }

    // Get the translation values from data attributes
    this.clearText = this.deleteButtonTarget.dataset.clearValue;
    this.undoClearText = this.deleteButtonTarget.dataset.undoClearValue;

    // Check if there is already an image URL present (e.g., for an edit form)
    if (this.previewTarget.dataset.url) {
      this.existingImageUrl = this.previewTarget.dataset.url; // Store the existing image URL
      this.previewExistingImage();
    }

    this.updateHeight();
    this.updateDeleteButtonState();
  }

  preview(event) {
    console.log('preview method called', event)
    event.stopImmediatePropagation();
    const input = this.inputTarget;
    const previewContainer = this.previewTarget; // Container for the image preview
    const file = input.files[0]; // Get the selected file

    // Clear any existing preview (including the existing image if any)
    previewContainer.innerHTML = "";

    if (file) {
        const reader = new FileReader();

        reader.onload = (e) => {
            // Create a new image element
            const img = document.createElement("img");
            img.src = e.target.result; // Set the preview image's `src` to the file content
            if (this.imageClasses) {
                img.classList.add(...this.imageClasses.split(' '));
            } else {
                img.classList.add("img-fluid"); // Add Bootstrap class for responsiveness
            }
            img.style.maxHeight = "50vh"; // Ensure the image is responsive
            previewContainer.appendChild(img); // Append the image to the preview container

            this.updateHeight(); // Update the height of the container
            this.updateDeleteButtonState(); // Update button state to reflect that an image is present
        };

        reader.readAsDataURL(file); // Read the file to trigger the onload event
    } else {
        // If no file is selected, ensure the height is reset
        this.updateHeight();
    }

    this.deleteFieldTarget.value = '0'; // Reset delete field when a new file is selected
  }

  // Display the existing image if there's already a media URL (on edit forms)
  previewExistingImage() {
    const previewContainer = this.previewTarget;

    // Clear any existing preview
    previewContainer.innerHTML = "";

    // Create and append the existing image to the preview container
    const img = document.createElement("img");
    img.src = this.existingImageUrl; // Use the stored image URL
    if (this.imageClasses) {
      img.classList.add(this.imageClasses);
    } else {
      img.classList.add("img-fluid"); // Add Bootstrap class for responsiveness
    }
    img.style.maxHeight = "50vh"; // Ensure the image is responsive
    previewContainer.appendChild(img);
    this.updateHeight(); // Update the height of the container
  }

  toggleDelete() {
    if (this.deleteFieldTarget.value === '0' && (this.inputTarget.files.length > 0 || this.existingImageUrl)) {
      this.deleteFieldTarget.value = '1'; // Mark for deletion
      this.clearInput();
    } else {
      this.deleteFieldTarget.value = '0'; // Unmark deletion
      if (this.inputTarget.files.length > 0) {
        this.preview(); // If there's a new file, re-trigger the preview
      } else if (this.existingImageUrl) {
        this.previewExistingImage(); // Restore the existing image preview
      }
    }
    this.updateDeleteButtonState(); // Update button state
  }

  clearInput() {
    this.inputTarget.value = ''; // Clear file input
    this.previewTarget.innerHTML = ''; // Clear the image preview
    this.updateHeight(); // Update the height of the container
  }

  updateDeleteButtonState() {
    const hasFile = this.inputTarget.files.length > 0; // Check if a new file has been selected
    const hasExistingImage = this.existingImageUrl; // Check if there is an existing image URL

    if (this.deleteFieldTarget.value === '1' && (hasFile || hasExistingImage)) {
        // When marked for deletion and there's an image to clear
        this.deleteButtonTarget.textContent = this.undoClearText; // Change button text
        this.deleteButtonTarget.classList.replace('btn-danger', 'btn-secondary'); // Change button style
    } else if (hasFile || hasExistingImage) {
        // When there's a file selected or an existing image
        this.deleteButtonTarget.textContent = this.clearText; // Reset button text
        this.deleteButtonTarget.classList.replace('btn-secondary', 'btn-danger'); // Reset button style
        this.deleteButtonTarget.disabled = false; // Ensure button is enabled
    } else {
        // When there's no file selected or existing image
        this.deleteButtonTarget.textContent = this.clearText; // Set text to 'Clear'
        this.deleteButtonTarget.classList.replace('btn-danger', 'btn-secondary'); // Set to a disabled look
        this.deleteButtonTarget.disabled = true; // Disable the button
    }
  }

  updateHeight() {
    const container = this.element; // Reference to the image-fields container
    const hasImage = this.previewTarget.innerHTML.trim().length > 0;

    if (hasImage) {
      container.classList.add("expanded");
    } else {
      container.classList.remove("expanded");
    }
  }
}
