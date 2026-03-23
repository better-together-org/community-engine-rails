# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Requests aggregated matches', :as_user do
  # rubocop:todo RSpec/MultipleExpectations
  it 'shows Potential Matches for my requests with matching offers' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    # Current authenticated user creating a request
    current_user = BetterTogether::User.find_by(email: 'user@example.test') ||
                   FactoryBot.create(:better_together_user, :confirmed,
                                     email: 'user@example.test', password: 'SecureTest123!@#')
    my_person = current_user.person

    # Ensure both records share a category so they match
    cat = create(:better_together_joatu_category)

    my_request = create(:better_together_joatu_request, creator: my_person, categories: [cat])
    other_offer = create(:better_together_joatu_offer, categories: [cat])

    # Visit the requests index
    get better_together.joatu_requests_path(locale: I18n.locale)

    expect(response).to be_successful
    expect(response.body).to include('Potential Matches')
    expect_html_content(my_request.name) # Use HTML assertion helper
    expect_html_content(other_offer.name) # Use HTML assertion helper
  end
end
