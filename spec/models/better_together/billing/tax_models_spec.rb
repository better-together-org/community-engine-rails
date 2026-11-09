# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing tax models' do # rubocop:disable RSpec/DescribeClass
  include_context 'with orders fixtures'

  let(:zone) { create(:better_together_billing_tax_zone, platform: host_platform) }

  describe BetterTogether::Billing::TaxCategory do
    it 'needs a unique lower-case identifier on its platform' do
      create(:better_together_billing_tax_category, platform: host_platform, identifier: 'produce')

      expect(build(:better_together_billing_tax_category, platform: host_platform, identifier: 'produce')).not_to be_valid
      expect(build(:better_together_billing_tax_category, platform: host_platform, identifier: 'Fresh Food')).not_to be_valid
    end
  end

  describe BetterTogether::Billing::TaxZone do
    let(:alberta) { tax_geography_state('CA', 'AB') }
    let(:town) { create(:geography_settlement, country: alberta.country, state: alberta) }

    let(:at_place) { ->(**args) { BetterTogether::Billing::Tax::Place.resolve(**args) } }

    it 'is tied to geography rows and says whether it is a country, state or municipal zone' do
      country = create(:better_together_billing_tax_zone, platform: host_platform)
      state = create(:better_together_billing_tax_zone, platform: host_platform, region_code: 'AB')
      municipal = create(:better_together_billing_tax_zone, platform: host_platform, settlement: town, state: nil, country: nil,
                                                            region_code: nil)

      expect([country.level, state.level, municipal.level]).to eq(%i[country state municipal])
      expect(municipal).to have_attributes(state: alberta, country: alberta.country)
    end

    it 'covers the country, the state and the settlement a place is in, and no others' do
      country = create(:better_together_billing_tax_zone, platform: host_platform)
      state = create(:better_together_billing_tax_zone, platform: host_platform, region_code: 'AB')
      municipal = create(:better_together_billing_tax_zone, platform: host_platform, settlement: town, state: nil, country: nil,
                                                            region_code: nil)
      other_state = create(:better_together_billing_tax_zone, platform: host_platform, region_code: 'BC')

      expect(described_class.covering(at_place.call(country_iso: 'CA'))).to contain_exactly(country)
      expect(described_class.covering(at_place.call(country_iso: 'CA', region_code: 'AB'))).to contain_exactly(country, state)
      expect(described_class.covering(at_place.call(settlement: town))).to contain_exactly(country, state, municipal)
      expect(described_class.covering(at_place.call(country_iso: 'CA', region_code: 'BC'))).to contain_exactly(country, other_state)
    end

    it 'refuses a state of another country, and a settlement outside its state' do
      other_country = tax_geography_country('US')
      elsewhere = create(:geography_settlement, country: other_country, state: create(:geography_state, country: other_country))

      expect(build(:better_together_billing_tax_zone, platform: host_platform, state: alberta, country: other_country)).not_to be_valid
      expect(build(:better_together_billing_tax_zone, platform: host_platform, state: alberta, country: alberta.country, settlement: elsewhere))
        .not_to be_valid
    end
  end

  describe BetterTogether::Billing::TaxRate do
    it 'is a fraction below one and ends after it starts' do
      expect(build(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, rate: 5)).not_to be_valid
      expect(build(:better_together_billing_tax_rate, platform: host_platform, tax_zone: zone, starts_at: 1.day.from_now, ends_at: Time.current))
        .not_to be_valid
    end

    it 'cannot use a zone or category from another platform' do
      other = create(:better_together_platform)
      foreign_zone = create(:better_together_billing_tax_zone, platform: other)

      expect(build(:better_together_billing_tax_rate, platform: host_platform, tax_zone: foreign_zone)).not_to be_valid
    end
  end

  describe BetterTogether::Billing::TaxRegistration do
    it 'keeps its registration number encrypted and knows whether it collects' do
      registration = create(:better_together_billing_tax_registration, platform: host_platform)

      expect(registration.registration_number).to eq('123456789RT0001')
      stored = described_class.connection.select_value("SELECT registration_number FROM #{described_class.table_name}")
      expect(stored).not_to include('123456789')
      expect(registration.collects?).to be(true)
      expect(build(:better_together_billing_tax_registration, status: 'exempt').collects?).to be(false)
      expect(build(:better_together_billing_tax_registration, status: 'nonsense')).not_to be_valid
    end

    it 'falls back to the country way of showing prices unless told' do
      expect(build(:better_together_billing_tax_registration, country_iso: 'CA').prices_include_tax?).to be(false)
      expect(build(:better_together_billing_tax_registration, country_iso: 'GB').prices_include_tax?).to be(true)
      expect(build(:better_together_billing_tax_registration, country_iso: 'GB', prices_include_tax: false).prices_include_tax?).to be(false)
    end
  end
end
