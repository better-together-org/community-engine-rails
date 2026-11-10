# frozen_string_literal: true

require 'rails_helper'

# One order, every place it is shown: the figures must be the same on each.
RSpec.describe 'Billing order summary across surfaces' do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with quebec tax'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash', tax_address: quebec_address) }
  let(:summary) { BetterTogether::Billing::Orders::Summary.for_order(order) }
  let(:money) { ->(cents) { Class.new { include ActionView::Helpers::NumberHelper, BetterTogether::BillingHelper }.new.billing_amount(cents, order.currency) } }
  let(:figures) do
    [summary.subtotal_cents, summary.total_cents, *summary.tax_rows.map(&:amount_cents)].map { |cents| money.call(cents) }
  end
  let(:numbers) { summary.registrations.map(&:number) }

  def text_of(html) = Nokogiri::HTML(html).text.squish

  it 'shows identical figures and registration numbers on the order page, offline instructions and email', :aggregate_failures do
    sign_in buyer_user
    get "/#{locale}/billing/orders/#{order.id}"
    page = text_of(response.body)
    notifier = BetterTogether::Billing::Notifier.new(record: order, params: { kind: 'order_paid', audience: :buyer })
    mail = BetterTogether::BillingMailer.with(recipient: buyer, notifier:).notification

    expect(response.body).to include("billing-summary-offline-#{order.offline_payments.first.id}", 'billing-summary-order')
    expect([page, text_of(mail.html_part.body.decoded), mail.text_part.body.decoded.squish]).to all(include(*figures, *numbers))
  end

  it 'has tax rows that sum to the tax and a total that is the subtotal plus the added tax', :aggregate_failures do
    expect(summary.tax_rows.sum(&:amount_cents)).to eq(order.tax_cents)
    expect(summary.subtotal_cents + summary.added_tax_cents).to eq(order.total_cents)
  end

  it 'carries no payment instructions in the email, whatever the summary shows', :aggregate_failures do
    notifier = BetterTogether::Billing::Notifier.new(record: order, params: { kind: 'order_placed', audience: :buyer })
    mail = BetterTogether::BillingMailer.with(recipient: buyer, notifier:).notification

    expect(mail.html_part.body.decoded + mail.text_part.body.decoded).not_to include('Alex', 'hall')
  end
end
