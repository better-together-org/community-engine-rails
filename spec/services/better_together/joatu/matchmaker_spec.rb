# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Joatu
    # rubocop:disable Metrics/BlockLength
    RSpec.describe Matchmaker do
      it 'matches offers by category and excludes same creator' do # rubocop:todo RSpec/ExampleLength
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

      it 'only matches offers with the same target' do # rubocop:todo RSpec/ExampleLength
        requestor = create(:better_together_person)
        offeror = create(:better_together_person)
        category = create(:better_together_joatu_category)

        target = create(:better_together_platform_invitation)
        other_target = create(:better_together_platform_invitation)

        matching_offer = create(
          :better_together_joatu_offer,
          creator: offeror,
          target: target
        )
        matching_offer.categories << category

        non_matching_offer = create(:better_together_joatu_offer, target: other_target)
        non_matching_offer.categories << category

        request = create(
          :better_together_joatu_request,
          creator: requestor,
          target: target
        )
        request.categories << category

        matches = described_class.match(request)

        expect(matches).to contain_exactly(matching_offer)
      end
    end
    # rubocop:enable Metrics/BlockLength
  end
end
