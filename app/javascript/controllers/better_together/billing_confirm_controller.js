// Puts the amount a steward has typed into the confirmation shown before a money-moving form is sent.
//
// The form always carries a complete data-turbo-confirm (naming the full amount), so it still asks without
// JavaScript. While an amount is typed, this swaps in the message that names that amount instead.
import { Controller } from '@hotwired/stimulus';

export default class extends Controller {
  static targets = ['amount', 'currency'];
  static values = { template: String, currency: String, fallback: String };

  connect() {
    this.update();
  }

  update() {
    const typed = this.hasAmountTarget ? this.amountTarget.value.trim() : '';
    const currency = this.hasCurrencyTarget ? this.currencyTarget.value : this.currencyValue;
    const message = typed ? this.templateValue.replace('{amount}', `${typed} ${currency}`) : this.fallbackValue;
    this.element.setAttribute('data-turbo-confirm', message);
  }
}
