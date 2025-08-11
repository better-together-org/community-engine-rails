# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Offer, type: :model do
      subject(:offer) { build(:better_together_joatu_offer) }

      it 'is valid with valid attributes' do
        expect(offer).to be_valid
      end

      it 'is invalid without a creator' do
        offer.creator = nil
        expect(offer).not_to be_valid
      end

      it 'is invalid without categories' do
        offer.categories = []
        expect(offer).not_to be_valid
      end
    end
  end
end
