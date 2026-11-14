# frozen_string_literal: true

require 'rails_helper'

# Placing an order adds the tax the seller (or else the platform) is registered to collect, and keeps it as charged.
RSpec.describe BetterTogether::Billing::Orders::Place, '.call with tax' do
  include_context 'with offline payment fixtures'

  let!(:registration) { create(:better_together_billing_tax_registration, platform: host_platform) }

  before do
    zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA')
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'GST', rate: 0.05)
  end

  it 'adds tax to the total and keeps it on the order, the line and a tax line' do
    order = place_order

    expect(order).to have_attributes(subtotal_cents: 4500, tax_cents: 225, included_tax_cents: 0, total_cents: 4725,
                                     tax_registration: registration, tax_country_iso: 'CA', prices_include_tax: false)
    expect(order.line_items.first).to have_attributes(tax_cents: 225, included_tax_cents: 0)
    expect(order.tax_lines.map { |line| [line.label, line.rate.to_f, line.amount_cents] }).to eq([['GST', 0.05, 225]])
  end

  it 'finds a municipal tax from the buyer settlement and keeps the settlement on the order' do
    state = tax_geography_state('CA', 'AB')
    town = create(:geography_settlement, country: state.country, state:)
    municipal = create(:better_together_billing_tax_zone, platform: host_platform, settlement: town, country: nil, state: nil, name: town.name)
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: municipal, label: 'City sales tax', rate: 0.02)

    order = place_order(tax_address: { settlement: town })

    expect(order).to have_attributes(tax_cents: 315, total_cents: 4815, tax_settlement: town, tax_country_iso: 'CA', tax_region_code: 'AB')
    expect(order.tax_lines.map(&:label)).to contain_exactly('GST', 'City sales tax')
  end

  it 'does not add tax that is already in the price' do
    registration.update!(prices_include_tax: true)

    order = place_order

    expect(order).to have_attributes(subtotal_cents: 4500, tax_cents: 214, included_tax_cents: 214, total_cents: 4500)
  end

  it 'keeps the tax as charged when the rate changes later' do
    order = place_order
    BetterTogether::Billing::TaxRate.update_all(rate: 0.1) # rubocop:disable Rails/SkipsModelValidations

    expect(order.reload.tax_lines.first).to have_attributes(rate: 0.05, amount_cents: 225, authority: 'gst_hst')
  end

  it 'checks payment parts against the total with tax' do
    enable_offline('cash')

    expect { place_order(payments: [{ payment_method: 'cash', amount_cents: 4725 }]) }.not_to raise_error
    expect { place_order(payments: [{ payment_method: 'cash', amount_cents: 4726 }]) }
      .to raise_error(described_class::Refused, /more than the order/)
  end

  it 'leaves orders alone when the seller is not registered to collect' do
    registration.update!(status: 'small_supplier_exempt')

    expect(place_order).to have_attributes(total_cents: 4500, tax_cents: 0, tax_registration: nil)
  end
end
