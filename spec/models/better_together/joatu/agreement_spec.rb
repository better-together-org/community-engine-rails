# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Agreement, type: :model do
      it 'accept! closes offer and request' do
        agreement = create(:better_together_joatu_agreement)
        agreement.accept!

        expect(agreement.status_accepted?).to be(true)
        expect(agreement.offer.status_closed?).to be(true)
        expect(agreement.request.status_closed?).to be(true)
      end

      describe 'validation' do
        it 'rejects mismatched targets' do
          request = create(:better_together_joatu_request)
          offer = create(:better_together_joatu_offer)

          allow(request).to receive(:target_type).and_return('Foo')
          allow(request).to receive(:target_id).and_return('1')
          allow(offer).to receive(:target_type).and_return('Foo')
          allow(offer).to receive(:target_id).and_return('2')

          agreement = described_class.new(offer:, request:)

          expect(agreement).not_to be_valid
          expect(agreement.errors[:offer]).to include('target does not match request target')
        end

        it 'allows matching targets' do
          request = create(:better_together_joatu_request)
          offer = create(:better_together_joatu_offer)

          allow(request).to receive(:target_type).and_return('Foo')
          allow(request).to receive(:target_id).and_return('1')
          allow(offer).to receive(:target_type).and_return('Foo')
          allow(offer).to receive(:target_id).and_return('1')

          agreement = described_class.new(offer:, request:)

          expect(agreement).to be_valid
        end
      end
    end
  end
end
