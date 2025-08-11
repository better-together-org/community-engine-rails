# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Offer, type: :model do
      subject(:offer) { build(:better_together_joatu_offer) }

      it 'is valid without a target' do
        expect(offer).to be_valid
      end

      it 'is valid with a target' do
        offer_with_target = build(:better_together_joatu_offer, :with_target)
        expect(offer_with_target).to be_valid
      end

      it 'is valid with only a target_type' do
        offer_with_type = build(:better_together_joatu_offer, :with_target_type)
        expect(offer_with_type).to be_valid
      end

      it 'is invalid without a creator' do
        offer.creator = nil
        expect(offer).not_to be_valid
      end

      it 'is invalid without target_type when target_id is set' do
        offer.target_id = SecureRandom.uuid
        offer.target_type = nil
        expect(offer).not_to be_valid
      end
    end
  end
end
