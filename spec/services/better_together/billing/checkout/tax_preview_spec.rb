# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Checkout::TaxPreview do
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'

  let(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, billing_interval: 'one_time', currency: 'USD', amount_cents: 2500)
  end
  let(:address) { create_billing_address_for(create(:better_together_person)) }
  let!(:registration) { create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA') }

  before do
    zone = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'NL')
    create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'HST', rate: 0.15)
  end

  def preview(addr = address) = described_class.new(platform: host_platform, plan:, address: addr)

  it 'promises nothing without an address' do
    expect(preview(nil)).to have_attributes(known?: false, taxed?: false, tax_cents: 0, total_cents: 2500, groups: [])
  end

  it 'shows the tax a new order would carry, and the total with it' do
    expect(preview).to have_attributes(known?: true, taxed?: true, tax_cents: 375, added_cents: 375, total_cents: 2875)
    expect(preview.groups.map { |g| [g.label, g.amount_cents] }).to eq([['HST', 375]])
  end

  it 'leaves the total alone when prices include tax' do
    registration.update!(prices_include_tax: true)

    expect(preview).to have_attributes(taxed?: true, added_cents: 0, total_cents: 2500)
  end

  it 'is not taxed where there is no registration' do
    registration.update!(country_iso: 'DE')

    expect(preview).to have_attributes(taxed?: false, total_cents: 2500)
  end
end
