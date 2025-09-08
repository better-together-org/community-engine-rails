# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Offers aggregated matches', :as_user do
  # rubocop:todo RSpec/MultipleExpectations
  it 'shows Potential Matches for my offers with matching requests' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    # Current authenticated user creating an offer
    current_user = BetterTogether::User.find_by(email: 'user@example.test') ||
                   FactoryBot.create(:better_together_user, :confirmed,
                                     email: 'user@example.test', password: 'password12345')
    my_person = current_user.person

    # Ensure both records share a category so they match
    cat = create(:better_together_joatu_category)

    my_offer = create(:better_together_joatu_offer, creator: my_person, categories: [cat])
    other_request = create(:better_together_joatu_request, categories: [cat])

    # Visit the offers index
    get better_together.joatu_offers_path(locale: I18n.locale)

    expect(response).to be_successful
    expect(response.body).to include('Potential Matches')
    expect(response.body).to include(other_request.name)
    expect(response.body).to include(my_offer.name)
  end
end
