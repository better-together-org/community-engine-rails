# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Joatu::ResponseLinksController, :as_user do
  let(:user) { create(:user, :confirmed, password: 'SecureTest123!@#') }
  let(:person) { user.person }
  let(:offer) { create(:better_together_joatu_offer, creator: person) }
  let(:request_resource) { create(:better_together_joatu_request) }

  # rubocop:todo RSpec/MultipleExpectations
  it 'prevents creating a response when source is closed' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    offer.update!(status: 'closed')
    post joatu_response_links_path(locale: I18n.locale), params: { source_type: 'BetterTogether::Joatu::Offer', source_id: offer.id }

    expect(response).to redirect_to(joatu_hub_path)
    follow_redirect!
    expect(response.body).to include('Cannot respond to a source that is not open or matched')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'creates a response and marks the source matched when allowed' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    request_resource.update!(status: 'open')
    post joatu_response_links_path(locale: I18n.locale), params: { source_type: 'BetterTogether::Joatu::Request', source_id: request_resource.id }

    # Expect redirect to the newly created offer's show path
    created_offer = BetterTogether::Joatu::Offer.order(:created_at).last
    expect(response).to redirect_to(joatu_offer_path(created_offer))
    expect(request_resource.reload.status).to eq('matched')
  end
end
