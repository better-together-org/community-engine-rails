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
    it 'upcases its place and covers the country and, when given, the region' do
      create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'ca', region_code: 'bc')
      country = create(:better_together_billing_tax_zone, platform: host_platform, country_iso: 'CA')

      expect(described_class.covering('CA', 'BC').count).to eq(2)
      expect(described_class.covering('CA', nil)).to contain_exactly(country)
      expect(build(:better_together_billing_tax_zone, country_iso: 'Canada')).not_to be_valid
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
