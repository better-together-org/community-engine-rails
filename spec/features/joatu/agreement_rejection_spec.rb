# frozen_string_literal: true

require 'rails_helper'

RSpec.feature 'Joatu agreement rejection', type: :feature do
  scenario 'rejects an agreement without closing offer or request' do
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
    expect(offer.status_open?).to be(true)
    expect(request.status_open?).to be(true)
  end
end
