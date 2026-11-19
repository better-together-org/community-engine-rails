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

  it 'reads Item, Tax, Quantity, Amount, with the amount last and in the column of the subtotal, taxes and total', :aggregate_failures do
    sign_in buyer_user
    get "/#{locale}/billing/orders/#{order.id}"
    table = Nokogiri::HTML(response.body).at_css('#billing-order-line-items')
    notifier = BetterTogether::Billing::Notifier.new(record: order, params: { kind: 'order_paid', audience: :buyer })
    email = Nokogiri::HTML(BetterTogether::BillingMailer.with(recipient: buyer, notifier:).notification.html_part.body.decoded)

    [table, email.at_css('#billing-email-line-items')].each do |t|
      expect(t.css('thead th').map { |th| th.text.squish }).to eq(%w[Item Tax Quantity Amount])
    end
    expect(table.css('tfoot tr').map { |tr| tr.element_children.last.name }.uniq).to eq(['td'])
    expect(table.css('tfoot tr').map { |tr| tr.element_children.size }.uniq).to eq([2])
    expect(table.at_css('tfoot tr th')['colspan']).to eq('3')
  end

  it 'says Taxed only on a taxed line: the Tax cell of a line without tax is empty, on every surface', :aggregate_failures do
    zero = create(:better_together_billing_tax_category, platform: host_platform, identifier: 'zero_rated', name: 'Zero rated', taxable: false)
    book = create(:better_together_billing_plan, :unlinked, processor: nil, billing_interval: 'one_time', currency: plan.currency,
                                                            amount_cents: 1500, name: 'Printed guide', tax_category: zero)
    enable_offline('cash')
    mixed = place_order(payment_method: 'cash', tax_address: quebec_address, line_items: [{ purchasable: plan }, { purchasable: book }])
    sign_in buyer_user
    get "/#{locale}/billing/orders/#{mixed.id}"
    notifier = BetterTogether::Billing::Notifier.new(record: mixed, params: { kind: 'order_paid', audience: :buyer })
    mail = BetterTogether::BillingMailer.with(recipient: buyer, notifier:).notification
    page = Nokogiri::HTML(response.body)
    email = Nokogiri::HTML(mail.html_part.body.decoded)

    expect(page.css('#billing-order-line-0-tax, #billing-order-line-1-tax').map { |td| td.text.squish }).to eq(['Taxed', ''])
    expect(%w[#billing-email-line-0 #billing-email-line-1].map { |row| email.css("#{row} td")[1].text.squish }).to eq(['Taxed', ''])
    expect(text_of(response.body) + mail.html_part.body.decoded + mail.text_part.body.decoded).not_to match(/Not taxed/i)
    expect(mail.text_part.body.decoded.lines.grep(/Printed guide/).first).not_to include('Taxed')
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
