# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Agreement do
      it 'accept! closes offer and request' do # rubocop:todo RSpec/MultipleExpectations
        agreement = create(:better_together_joatu_agreement)
        agreement.accept!

        expect(agreement.status_accepted?).to be(true)
        expect(agreement.offer.status_closed?).to be(true)
        expect(agreement.request.status_closed?).to be(true)
      end

      describe 'validation' do
        # rubocop:todo RSpec/MultipleExpectations
        it 'rejects mismatched targets' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
          # rubocop:enable RSpec/MultipleExpectations
          request = create(:better_together_joatu_request)
          offer = create(:better_together_joatu_offer)

          allow(request).to receive_messages(target_type: 'Foo', target_id: '1')
          allow(offer).to receive_messages(target_type: 'Foo', target_id: '2')

          agreement = described_class.new(offer:, request:)

          expect(agreement).not_to be_valid
          expect(agreement.errors[:offer]).to include('target does not match request target')
        end

        it 'allows matching targets' do # rubocop:todo RSpec/ExampleLength
          request = create(:better_together_joatu_request)
          offer = create(:better_together_joatu_offer)

          allow(request).to receive_messages(target_type: 'Foo', target_id: '1')
          allow(offer).to receive_messages(target_type: 'Foo', target_id: '1')

          agreement = described_class.new(offer:, request:)

          expect(agreement).to be_valid
        end
      end

      # rubocop:todo RSpec/MultipleExpectations
      it 'marks offer and request as matched on create if open' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
        # rubocop:enable RSpec/MultipleExpectations
        offer = create(:better_together_joatu_offer)
        request = create(:better_together_joatu_request)

        offer.update!(status: 'open')
        request.update!(status: 'open')

        agreement = described_class.create!(offer: offer, request: request, status: 'pending')

        expect(agreement.offer.reload.status).to eq('matched')
        expect(agreement.request.reload.status).to eq('matched')
      end
    end
  end
end
