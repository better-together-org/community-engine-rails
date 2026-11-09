# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    module Tax
      module Seeds
        RSpec.describe Canada do
          let(:platform) { BetterTogether::Platform.find_by(host: true) || create(:better_together_platform, :host) }

          def rate_for(region, label) = TaxRate.joins(:tax_zone).find_by(tax_zone: { region_code: region }, label:).rate

          it 'adds a zone for every province and territory with the rates that apply there' do
            described_class.call(platform:)

            expect(TaxZone.where(platform:, country_iso: 'CA').count).to eq(13)
            expect(rate_for('ON', 'HST')).to eq(BigDecimal('0.13'))
            expect(rate_for('NS', 'HST')).to eq(BigDecimal('0.14'))
            expect(rate_for('QC', 'QST')).to eq(BigDecimal('0.09975'))
            expect(TaxRate.joins(:tax_zone).where(tax_zone: { region_code: 'AB' }).pluck(:label)).to eq(['GST'])
          end

          it 'adds a category for basic groceries that is not taxed' do
            described_class.call(platform:)

            expect(TaxCategory.find_by(platform:, identifier: 'basic_groceries')).not_to be_taxable
            expect(TaxCategory.find_by(platform:, identifier: 'standard')).to be_taxable
          end

          it 'adds nothing the second time and leaves a changed rate alone' do
            described_class.call(platform:)
            TaxRate.joins(:tax_zone).find_by(tax_zone: { region_code: 'BC' }, label: 'PST').update!(rate: 0.08)

            expect { described_class.call(platform:) }.not_to change(TaxRate, :count)
            expect(rate_for('BC', 'PST')).to eq(BigDecimal('0.08'))
          end

          it 'charges the right tax in a province it seeded' do
            described_class.call(platform:)
            registration = create(:better_together_billing_tax_registration, platform:, country_iso: 'CA', region_code: 'SK')

            result = Calculator.call(platform:, seller: nil, country_iso: 'CA', region_code: 'SK',
                                     items: [Calculator::Item.new(amount_cents: 10_000, tax_category: nil)])

            expect(registration).to be_collects
            expect(result.tax_cents).to eq(1100)
          end
        end
      end
    end
  end
end
