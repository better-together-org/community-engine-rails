import { Controller } from "@hotwired/stimulus"

export default class extends Controller {

  static targets = ["field", 'icon']

  password(e) {
    e.preventDefault();
    var password_field = this.fieldTarget;
    var icon = this.iconTarget;

    if (password_field.type === "password") {
      icon.classList.remove('fa-eye-slash');
      icon.classList.add('fa-eye');
      password_field.type = "text";
    } else {
      icon.classList.remove('fa-eye');
      icon.classList.add('fa-eye-slash');
      password_field.type = "password";
    }
  }
}