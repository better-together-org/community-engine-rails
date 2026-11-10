// Keeps the checkout's tax summary in step with the billing address picker.
//
// The summary sits in a Turbo Frame. When the buyer picks another address, the frame is pointed at the checkout page
// for that address, so only the summary is replaced; the amounts, ticked agreements and typed address are untouched.
// Choosing "new address" asks for the page with no known address, which says tax is worked out once it is entered.
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static values = { frameId: String, url: String, planId: String };

  refresh(event) {
    const frame = document.getElementById(this.frameIdValue);
    if (!frame) return;

    const params = new URLSearchParams({ plan_id: this.planIdValue, billing_address_id: event.target.value });
    const method = document.querySelector('input[name="payment_method"]:checked');
    if (method) params.set('payment_method', method.value);
    frame.src = `${this.urlValue}?${params.toString()}`;
  }
}
