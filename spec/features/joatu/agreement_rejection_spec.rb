# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Joatu agreement rejection' do
  # rubocop:todo RSpec/MultipleExpectations
  scenario 'rejects an agreement without closing offer or request' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    requestor = create(:better_together_person)
    offeror = create(:better_together_person)
    category = create(:better_together_joatu_category)

    offer = create(:better_together_joatu_offer, creator: offeror)
    offer.categories << category

    request = create(:better_together_joatu_request, creator: requestor)
    request.categories << category

    agreement = BetterTogether::Joatu::Agreement.create!(offer:, request:, terms: 'Repair help', value: '20 credits')
    agreement.reject!

    expect(agreement.status_rejected?).to be(true)
    # Agreement creation marks associated offer/request as matched; rejecting the agreement leaves them matched
    expect(offer.status_matched?).to be(true)
    expect(request.status_matched?).to be(true)
  end
end
