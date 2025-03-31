import { Controller } from "@hotwired/stimulus";
import "masonry";
// import "imagesloaded";

// filepath: app/javascript/controllers/better_together/tabs_controller.js

export default class extends Controller {

  connect() {
    this.masonry = new Masonry(this.element, {
      itemSelector: '.col',
      percentPosition: true,
      fitWidth: true
    })
    // this.imagesLoaded = imagesLoaded(this.element).progress(function() {
    //   this.masonry('layout')
    // })
  }
}