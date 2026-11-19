# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe ProcessorContext do
      let(:platform) { create(:better_together_platform) }

      it 'defaults to an environment source and normalises the processor to a symbol' do
        context = described_class.new(platform:, processor: 'stripe')

        expect(context).to have_attributes(platform:, processor: :stripe, source: :environment,
                                           account_ref: nil, credentials: nil)
        expect(context).to be_environment
      end

      it 'needs a platform, because a call with no tenant must not be made' do
        expect { described_class.new(platform: nil, processor: :stripe) }
          .to raise_error(ArgumentError, /needs a platform/)
      end

      it 'carries an account reference and freezes any credentials it is given' do
        context = described_class.new(platform:, processor: :stripe, source: :database,
                                      account_ref: 'acct_1', credentials: { api_key: 'k' })

        expect(context).not_to be_environment
        expect(context.account_ref).to eq('acct_1')
        expect(context.credentials).to be_frozen
      end
    end
  end
end
