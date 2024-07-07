// app/javascripts/better_together/controllers/trix_controller.js

import { Controller } from "@hotwired/stimulus";

export default class TrixController extends Controller {

  connect() {

    // wait for the trix editor is attached to the DOM to do stuff
    addEventListener("trix-initialize", function (event) {
      console.log("im inititalized!");
      // ...
      // add underline code
      // remove buttons code
      // add custom icons code here
      // ...
    }, true);
  }
}
