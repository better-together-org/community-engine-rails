# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::Tax::Calculator do
  include_context 'with orders fixtures'

  def item(amount_cents, category: nil) = described_class::Item.new(amount_cents:, tax_category: category)

  def calculate(items:, **attrs) = described_class.call(platform: host_platform, items:, **attrs)

  let!(:registration) { create(:better_together_billing_tax_registration, platform: host_platform) }
  let!(:zone) { create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA') }
  let!(:gst) { create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, label: 'GST', rate: 0.05) }

  it 'adds tax on top of the price when prices exclude tax (the Canadian default)' do
    result = calculate(items: [item(4500)])

    expect(result).to have_attributes(taxed?: true, tax_cents: 225, included_cents: 0, additional_cents: 225, prices_include_tax: false)
    expect(result.lines.first).to have_attributes(label: 'GST', rate: 0.05, amount_cents: 225, included: false, tax_rate: gst)
  end

  it 'takes tax out of the price when prices include tax, leaving the total alone' do
    registration.update!(prices_include_tax: true)

    result = calculate(items: [item(1050)])

    expect(result).to have_attributes(tax_cents: 50, included_cents: 50, additional_cents: 0, prices_include_tax: true)
  end

  it 'starts from the country usual way of showing prices when the registration does not say' do
    registration.update!(country_iso: 'DE')
    german = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'DE')
    create(:better_together_billing_tax_rate, platform: host_platform, label: 'VAT', rate: 0.19, tax_zone: german)

    expect(calculate(items: [item(11_900)])).to have_attributes(prices_include_tax: true, tax_cents: 1900, additional_cents: 0)
  end

  it 'rounds half up to the minor unit' do
    expect(calculate(items: [item(10)]).tax_cents).to eq(1) # 0.5 rounds up
    expect(calculate(items: [item(9)]).tax_cents).to eq(0)  # 0.45 rounds down
  end

  it 'applies every rate for the place: the country and the region' do
    british_columbia = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA', region_code: 'BC')
    create(:better_together_billing_tax_rate, platform: host_platform, label: 'PST', rate: 0.07, tax_zone: british_columbia)

    result = calculate(items: [item(10_000)], country_iso: 'CA', region_code: 'BC')

    expect(result.lines.map { |line| [line.label, line.amount_cents] }).to contain_exactly(['GST', 500], ['PST', 700])
    expect(calculate(items: [item(10_000)], country_iso: 'CA', region_code: 'ON').tax_cents).to eq(500)
  end

  it 'works out tax for the buyer place when given, else for the registrant place' do
    expect(calculate(items: [item(1000)], country_iso: 'US').taxed?).to be(false)
    expect(calculate(items: [item(1000)])).to have_attributes(country_iso: 'CA', taxed?: true)
  end

  it 'does not tax a category that is not taxable' do
    produce = create(:better_together_billing_tax_category, platform: host_platform, identifier: 'produce', taxable: false)

    result = calculate(items: [item(1000, category: produce), item(1000)])

    expect(result.lines.map(&:item_index)).to eq([1])
    expect(result.lines_for(0)).to be_empty
  end

  it 'applies a rate only to its own category when it has one' do
    books = create(:better_together_billing_tax_category, platform: host_platform, identifier: 'books')
    gst.update!(tax_category: books)

    expect(calculate(items: [item(1000)]).taxed?).to be(false)
    expect(calculate(items: [item(1000, category: books)]).tax_cents).to eq(50)
  end

  it 'ignores rates that have not started, have ended or were discarded' do
    gst.update!(starts_at: 1.day.from_now)
    expect(calculate(items: [item(1000)]).taxed?).to be(false)

    gst.update!(starts_at: 2.days.ago, ends_at: 1.day.ago)
    expect(calculate(items: [item(1000)]).taxed?).to be(false)

    gst.update!(starts_at: nil, ends_at: nil)
    gst.discard!
    expect(calculate(items: [item(1000)]).taxed?).to be(false)
  end

  it 'charges no tax when there is no registration or it does not collect' do
    %w[small_supplier_exempt exempt not_collecting].each do |status|
      registration.update!(status:)
      expect(calculate(items: [item(1000)]).taxed?).to be(false), status
    end

    registration.destroy!
    expect(calculate(items: [item(1000)]).taxed?).to be(false)
  end

  it 'uses the seller own registration, else the platform one' do
    seller = create(:better_together_person)
    expect(calculate(items: [item(1000)], seller:).tax_cents).to eq(50)

    create(:better_together_billing_tax_registration, platform: host_platform, seller:, status: 'small_supplier_exempt')
    expect(calculate(items: [item(1000)], seller:).taxed?).to be(false)
    expect(calculate(items: [item(1000)]).tax_cents).to eq(50)
  end

  it 'leaves a registration out of force alone' do
    registration.update!(effective_to: 1.day.ago)

    expect(calculate(items: [item(1000)]).taxed?).to be(false)
  end

  describe 'a municipal tax' do
    let(:state) { tax_geography_state('CA', 'AB') }
    let(:town) { create(:geography_settlement, country: state.country, state:) }
    let(:other_town) { create(:geography_settlement, country: state.country, state:) }

    before do
      municipal = create(:better_together_billing_tax_zone, platform: host_platform, settlement: town, country: nil, state: nil, name: town.name)
      create(:better_together_billing_tax_rate, platform: host_platform, tax_zone: municipal, label: 'City sales tax', rate: 0.02)
    end

    it 'adds to the state and country tax for a buyer in that settlement' do
      result = calculate(items: [item(10_000)], settlement: town)

      expect(result.lines.map { |line| [line.label, line.amount_cents] }).to contain_exactly(['GST', 500], ['City sales tax', 200])
      expect(result).to have_attributes(settlement: town, country_iso: 'CA', region_code: 'AB')
    end

    it 'does not apply to a buyer in another settlement, or in none' do
      expect(calculate(items: [item(10_000)], settlement: other_town).tax_cents).to eq(500)
      expect(calculate(items: [item(10_000)], country_iso: 'CA', region_code: 'AB').tax_cents).to eq(500)
    end

    it 'takes the tax out of the price with the others when prices include tax' do
      registration.update!(prices_include_tax: true)

      result = calculate(items: [item(10_700)], settlement: town)

      expect(result).to have_attributes(tax_cents: 700, additional_cents: 0)
    end
  end
end
