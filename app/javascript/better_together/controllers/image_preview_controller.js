import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "preview"]

  connect() {
    // Check if there is already an image URL present (e.g., for an edit form)
    if (this.previewTarget.dataset.url) {
      this.previewExistingImage();
    }
    
    this.updateHeight();
  }

  preview() {
    const input = this.inputTarget;
    const previewContainer = this.previewTarget; // Container for the image preview
    const file = input.files[0]; // Get the selected file

    // Clear any existing preview
    previewContainer.innerHTML = "";

    if (file) {
      const reader = new FileReader();

      reader.onload = (e) => {
        // Create a new image element
        const img = document.createElement("img");
        img.src = e.target.result; // Set the preview image's `src` to the file content
        img.classList.add("img-fluid"); // Add Bootstrap class for responsiveness
        img.style.maxWidth = "100%"; // Ensure the image is responsive
        previewContainer.appendChild(img); // Append the image to the preview container
        
        this.updateHeight(); // Update the height of the container
      };

      reader.readAsDataURL(file); // Read the file to trigger the onload event
    } else {
      // If no file is selected, ensure the height is reset
      this.updateHeight();
    }
  }

  // Display the existing image if there's already a media URL (on edit forms)
  previewExistingImage() {
    const previewContainer = this.previewTarget;
    const url = this.previewTarget.dataset.url;

    // Create and append the existing image to the preview container
    const img = document.createElement("img");
    img.src = url; // Set the preview image's `src` to the existing media URL
    img.classList.add("img-fluid"); // Add Bootstrap class for responsiveness
    img.style.maxWidth = "100%"; // Ensure the image is responsive
    previewContainer.appendChild(img);
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
