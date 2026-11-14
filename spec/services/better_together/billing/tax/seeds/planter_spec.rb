# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Tax::Seeds::Planter do
  include_context 'with orders fixtures'

  let(:identifier) { 'billing_tax_canada' }
  let(:regions) { %w[AB BC MB NB NL NS NT NU ON PE QC SK YT] }

  def plant = described_class.call(platform: host_platform, identifier:)

  def plant_geography = regions.each { |region| tax_geography_state('CA', region) }

  def rates_for(region)
    host_platform.billing_tax_zones.find_by(state: tax_geography_state('CA', region)).tax_rates.to_h { |rate| [rate.label, rate.rate.to_f] }
  end

  it 'ships its packets as Seed envelopes' do
    expect(described_class.identifiers).to include(identifier)
  end

  it 'refuses to plant, and plants nothing, until the geography it names is there' do
    expect { plant }.to raise_error(described_class::Missing, /CA-AB is not planted/)

    tax_geography_country('CA')
    expect { plant }.to raise_error(described_class::Missing, /CA-AB/)
    expect(host_platform.billing_tax_zones).to be_empty
    expect(BetterTogether::Seed.where(identifier:)).to be_empty
  end

  it 'ties a zone to each seeded province and holds the rates in force there' do
    plant_geography

    plant

    expect(host_platform.billing_tax_zones.count).to eq(13)
    expect(host_platform.billing_tax_zones.map(&:state)).to match_array(regions.map { |region| tax_geography_state('CA', region) })
    expect(rates_for('AB')).to eq('GST' => 0.05)
    expect(rates_for('BC')).to eq('GST' => 0.05, 'PST' => 0.07)
    expect(rates_for('QC')).to eq('GST' => 0.05, 'QST' => 0.09975)
    expect(rates_for('NS')).to eq('HST' => 0.14)
    expect(rates_for('ON')).to eq('HST' => 0.13)
  end

  it 'records the packet as a Seed and adds a groceries category that is not taxed' do
    plant_geography

    plant

    expect(BetterTogether::Seed.find_by(identifier:)).to have_attributes(type: 'BetterTogether::Seed', version: '1.0')
    expect(host_platform.billing_tax_categories.find_by(identifier: 'basic_groceries').taxable).to be(false)
    expect(host_platform.billing_tax_categories.find_by(identifier: 'standard').taxable).to be(true)
  end

  it 'files each rate under its tax and adds the zero-rated and exempt categories' do
    plant_geography

    plant

    authorities = BetterTogether::Billing::TaxRate.where(platform: host_platform).to_h { |rate| [rate.label(locale: :en), rate.authority] }
    expect(authorities).to eq('GST' => 'gst_hst', 'HST' => 'gst_hst', 'PST' => 'pst', 'QST' => 'qst', 'RST' => 'rst')
    expect(host_platform.billing_tax_categories.where(identifier: %w[zero_rated exempt]).pluck(:taxable)).to eq([false, false])
  end

  it 'names the tax of a rate planted before authorities existed, without touching its rate' do
    plant_geography
    plant
    rate = host_platform.billing_tax_zones.find_by(state: tax_geography_state('CA', 'SK')).tax_rates.i18n.find_by(label: 'PST')
    rate.update_columns(authority: 'other') # rubocop:disable Rails/SkipsModelValidations

    expect { plant }.to change { rate.reload.authority }.from('other').to('pst')
    expect(rate.rate.to_f).to eq(0.06)
  end

  it 'only adds what is missing and never changes a rate that exists' do
    plant_geography
    plant
    rate = host_platform.billing_tax_zones.find_by(state: tax_geography_state('CA', 'SK')).tax_rates.i18n.find_by(label: 'PST')
    rate.update!(rate: 0.07)

    counts = -> { [host_platform.billing_tax_zones.count, BetterTogether::Billing::TaxRate.count, BetterTogether::Seed.count] }
    expect { plant }.not_to(change { counts.call })
    expect(rate.reload.rate.to_f).to eq(0.07)
  end

  it 'says whether the packet is planted' do
    plant_geography
    expect(described_class.planted?(platform: host_platform, identifier:)).to be(false)

    plant

    expect(described_class.planted?(platform: host_platform, identifier:)).to be(true)
  end

  it 'refuses a packet that does not ship' do
    expect { described_class.call(platform: host_platform, identifier: '../../etc/passwd') }.to raise_error(described_class::Missing)
  end

  it 'works out Saskatchewan tax from the planted zones' do
    plant_geography
    plant
    create(:better_together_billing_tax_registration, platform: host_platform, region_code: 'SK')

    result = BetterTogether::Billing::Tax::Calculator.call(
      platform: host_platform, country_iso: 'CA', region_code: 'SK',
      items: [BetterTogether::Billing::Tax::Calculator::Item.new(amount_cents: 10_000, tax_category: nil)]
    )

    expect(result.lines.map { |line| [line.label, line.amount_cents] }).to contain_exactly(['GST', 500], ['PST', 600])
  end

  it 'plants a municipal zone from a packet entry that names a settlement' do
    plant_geography
    state = tax_geography_state('CA', 'AB')
    town = create(:geography_settlement, country: state.country, state:, identifier: 'testville')
    planter = described_class.new(host_platform, identifier)
    planter.send(:plant_zone, { settlement_identifier: 'testville', name: 'Testville', rates: [{ label: 'City', rate: '0.01' }] })

    zone = host_platform.billing_tax_zones.find_by(settlement: town)
    expect(zone).to have_attributes(level: :municipal, state:, name: 'Testville')
    expect(zone.tax_rates.first.rate.to_f).to eq(0.01)
  end
end
