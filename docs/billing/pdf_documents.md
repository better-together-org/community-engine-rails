# PDF invoices and receipts

An order can be a PDF, in the same shape as the order pages and the emails: the same lines, the same row for each
tax, the same total and the same registration numbers. `Billing::Orders::Document` builds it from
`Orders::Summary`, so the figures cannot differ from one surface to another.

```ruby
BetterTogether::Billing::Orders::Document.new(order).to_pdf           # invoice while unpaid, receipt once paid
BetterTogether::Billing::Orders::Document.new(order, kind: :invoice)  # the invoice of a paid order
```

- **Layout.** Details (order, status, placed; paid and method on a receipt), then the buyer, then the lines
  (Item, Tax, Quantity, Amount; the Tax column only when the order has tax), then a right-aligned totals table so every
  amount lines up: subtotal, one row per tax with its rate and what it applies to, total. A receipt of an order with
  refunds adds the amount refunded and what is left paid. The registration numbers close the page.
- **Library.** The `receipts` gem (3.x), pure Ruby, with a bundled Inter font for Latin, Greek and Cyrillic, so all four
  locales (en, es, fr, uk) render. Pay's own `Pay::Receipts` mixin is for `Pay::Charge` and is not used: a billing
  order is not a charge, and Pay's mailers stay off (`Pay.send_emails = false`).
- **What is attached.** Only the buyer's emails: the invoice with "order placed", the receipt and the invoice with
  "order paid", the receipt with a refund. Sellers and operators get none.
- **What is never in it.** No payment instructions, payee details or processor text, like the email it travels in, so a
  forwarded copy cannot be used to redirect a payment. The file name carries only the order number
  (`invoice-<number>.pdf`, `receipt-<number>.pdf`).
- **Business details.** The company block reads `Pay.business_name`, `Pay.business_address` and `Pay.support_email`
  (from `PAY_BUSINESS_NAME`, `PAY_BUSINESS_ADDRESS`, `PAY_SUPPORT_EMAIL`), falling back to the platform name. `PAY_SUPPORT_EMAIL` falls back to `DEFAULT_FROM_EMAIL`, the app's from address.

## Pay 12

CE needs Pay 12.4 or later and receipts 3. Host apps that use Stripe through Pay also need `stripe ~> 20`, and
`payment_method_types` becomes `allowed_payment_method_types`; that is a Pay 12 change, not CE code. Pay 12 removed
`Pay::Subscription::STATUSES`; `Entitlements::State::STATUSES` is CE's own list. A status outside it (a processor can
report one Pay does not list, such as Braintree `expired`) is treated as lapsed and reported through
`BetterTogether.report_error`.
