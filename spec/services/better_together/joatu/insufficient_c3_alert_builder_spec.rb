# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::InsufficientC3AlertBuilder, type: :service do
  let(:person) { create(:better_together_person) }

  # rubocop:disable RSpec/VerifiedDoubles
  let(:controller) do
    double('controller',
           current_person: person,
           t: 'translated message',
           helpers: double('helpers', tree_seeds_display: '5 🌱'))
  end
  # rubocop:enable RSpec/VerifiedDoubles

  # rubocop:disable RSpec/VerifiedDoubles
  let(:offer) { double('offer', c3_price_millitokens: 5_000) }
  let(:request_record) { double('request', creator: person) }
  let(:agreement) { double('agreement', offer:, request: request_record) }
  # rubocop:enable RSpec/VerifiedDoubles

  before do
    allow(BetterTogether::C3::Balance).to receive(:find_by).and_return(nil)
  end

  describe '.call' do
    context 'when the payer is the current user' do
      it 'calls the current-user-specific i18n key' do
        described_class.call(agreement, controller)
        expect(controller).to have_received(:t).with(
          'flash.joatu.agreement.insufficient_c3',
          hash_including(needed: anything, current: anything, default: anything)
        )
      end

      it 'returns the translated message' do
        expect(described_class.call(agreement, controller)).to eq('translated message')
      end
    end

    context 'when the payer is a different person' do
      let(:other_person) { create(:better_together_person) }
      let(:request_record) { double('request', creator: other_person) } # rubocop:disable RSpec/VerifiedDoubles

      it 'calls the third-party payer i18n key' do
        described_class.call(agreement, controller)
        expect(controller).to have_received(:t).with(
          'flash.joatu.agreement.insufficient_c3_payer',
          hash_including(needed: anything, default: anything)
        )
      end
    end

    context 'when the agreement has no request' do
      let(:agreement) { double('agreement', offer:, request: nil) } # rubocop:disable RSpec/VerifiedDoubles

      it 'falls back to the payer message (creator is nil)' do
        described_class.call(agreement, controller)
        expect(controller).to have_received(:t).with(
          'flash.joatu.agreement.insufficient_c3_payer',
          hash_including(needed: anything)
        )
      end
    end

    context 'when the agreement has no offer' do
      let(:agreement) { double('agreement', offer: nil, request: request_record) } # rubocop:disable RSpec/VerifiedDoubles

      it 'treats the price as zero and still returns the current-user message' do
        described_class.call(agreement, controller)
        expect(controller).to have_received(:t).with(
          'flash.joatu.agreement.insufficient_c3',
          hash_including(needed: anything)
        )
      end
    end
  end
end
