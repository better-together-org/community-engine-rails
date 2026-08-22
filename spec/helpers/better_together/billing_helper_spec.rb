# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe BillingHelper do
    describe '#billing_amount' do
      it 'formats a known currency with its curated symbol' do
        expect(helper.billing_amount(4_500, 'CAD')).to eq('CA$45.00')
        expect(helper.billing_amount(4_500, 'USD')).to eq('US$45.00')
        expect(helper.billing_amount(4_500, 'EUR')).to eq('€45.00')
        expect(helper.billing_amount(4_500, 'GBP')).to eq('£45.00')
      end

      it 'is case-insensitive on the currency code' do
        expect(helper.billing_amount(4_500, 'cad')).to eq('CA$45.00')
      end

      it 'falls back to the raw upcased code for an uncurated currency' do
        expect(helper.billing_amount(4_500, 'JPY')).to eq('JPY 45.00')
      end
    end

    describe '#billing_interval_label' do
      it 'returns the localized label for a known interval' do
        expect(helper.billing_interval_label('month')).to eq('Monthly')
        expect(helper.billing_interval_label('year')).to eq('Yearly')
      end

      it 'humanizes an interval with no matching translation' do
        expect(helper.billing_interval_label('fortnight')).to eq('Fortnight')
      end
    end
  end
end
