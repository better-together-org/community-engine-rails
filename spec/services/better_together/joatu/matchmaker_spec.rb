# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    RSpec.describe Matchmaker do
      it 'matches offers by category and excludes same creator' do
        requestor = create(:better_together_person)
        offeror = create(:better_together_person)
        category = create(:better_together_joatu_category)
        other_category = create(:better_together_joatu_category)

        matching_offer = create(:better_together_joatu_offer, creator: offeror)
        matching_offer.categories << category

        create(:better_together_joatu_offer).tap { |o| o.categories << other_category }

        request = create(:better_together_joatu_request, creator: requestor)
        request.categories << category

        matches = described_class.match(request)

        expect(matches).to contain_exactly(matching_offer)
      end
    end
  end
end
