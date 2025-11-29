# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Joatu matchmaking' do
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'matches offers with requests and finalizes agreement' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    requestor = create(:better_together_person)
    offeror = create(:better_together_person)
    category = create(:better_together_joatu_category)

    offer = create(:better_together_joatu_offer, creator: offeror)
    offer.categories << category

    request = create(:better_together_joatu_request, creator: requestor)
    request.categories << category

    matches = BetterTogether::Joatu::Matchmaker.match(request)
    expect(matches).to include(offer)

    agreement = BetterTogether::Joatu::Agreement.create!(offer:, request:, terms: 'Repair help', value: '20 credits')
    agreement.accept!

    expect(agreement.status_accepted?).to be(true)
    expect(offer.status_closed?).to be(true)
    expect(request.status_closed?).to be(true)
  end
end
