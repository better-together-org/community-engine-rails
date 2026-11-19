# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::SeedCatalog::BillingTaxCatalog do
  include_context 'with orders fixtures'

  before do
    host_platform
    %w[AB BC MB NB NL NS NT NU ON PE QC SK YT].each { |region| tax_geography_state('CA', region) }
  end

  it 'is registered beside the geography catalog' do
    expect(BetterTogether::SeedCatalog::Registry.find(:billing_tax)).to eq(described_class)
  end

  it 'needs the geography countries and provinces first and says so by their label' do
    allow(BetterTogether::SeedCatalog::GeographyCatalog).to receive(:planted?).and_return(false)

    expect(described_class.missing_prerequisites(:billing_tax_canada)).to eq(%i[countries provinces])
    expect(described_class.category(:countries)[:label]).to eq('Countries')
    expect(described_class.category(:provinces)[:label]).to eq('Provinces & Territories')
    expect(described_class.plant(:billing_tax_canada)).to be(false)
  end

  it 'plants the packet on the host platform once, and reports it planted' do
    allow(BetterTogether::SeedCatalog::GeographyCatalog).to receive(:planted?).and_return(true)
    expect(described_class.planted?(:billing_tax_canada)).to be(false)

    expect(described_class.plant(:billing_tax_canada)).to be(true)

    expect(described_class.planted?(:billing_tax_canada)).to be(true)
    expect(host_platform.billing_tax_zones.count).to eq(13)
    expect { described_class.plant(:billing_tax_canada) }.not_to(change(BetterTogether::Billing::TaxZone, :count))
  end
end
