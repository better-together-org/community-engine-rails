# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Joatu block enforcement', :as_user do # rubocop:disable RSpec/DescribeClass
  let(:locale) { I18n.default_locale }
  let(:me) { BetterTogether::User.find_by(email: 'user@example.test').person }
  let(:other) { create(:better_together_person) }
  let(:category) { create(:better_together_joatu_category) }
  let!(:my_request) do
    create(:better_together_joatu_request, creator: me, status: 'open', privacy: 'public').tap { |r| r.categories << category }
  end
  let!(:their_offer) do
    create(:better_together_joatu_offer, creator: other, status: 'open', privacy: 'public',
                                         name: 'Blocked person offer').tap { |o| o.categories << category }
  end
  let!(:their_request) do
    create(:better_together_joatu_request, creator: other, status: 'open', privacy: 'public',
                                           name: 'Blocked person request')
  end

  shared_examples 'hides the other person exchange' do
    it 'omits their offers and requests from the indexes' do
      get "/#{locale}/exchange/offers"
      expect_no_html_content('Blocked person offer')

      get "/#{locale}/exchange/requests"
      expect_no_html_content('Blocked person request')
    end

    it 'does not show their offer or request directly' do
      get "/#{locale}/exchange/offers/#{their_offer.id}"
      expect(response).not_to have_http_status(:ok)

      get "/#{locale}/exchange/requests/#{their_request.id}"
      expect(response).not_to have_http_status(:ok)
    end

    it 'does not suggest their offer as a match' do
      get "/#{locale}/exchange/requests/#{my_request.id}/matches"
      expect_no_html_content('Blocked person offer')
    end

    it 'does not create an agreement or response link with them' do
      expect do
        post "/#{locale}/exchange/agreements", params: { offer_id: their_offer.id, request_id: my_request.id }
        post "/#{locale}/exchange/response_links", params: { source_type: 'BetterTogether::Joatu::Offer',
                                                             source_id: their_offer.id }
      end.not_to(change { [BetterTogether::Joatu::Agreement.count, BetterTogether::Joatu::ResponseLink.count] })
    end
  end

  context 'when I blocked them' do
    before { create(:person_block, blocker: me, blocked: other) }

    it_behaves_like 'hides the other person exchange'
  end

  context 'when they blocked me' do
    before { create(:person_block, blocker: other, blocked: me) }

    it_behaves_like 'hides the other person exchange'
  end

  it 'shows their offer when there is no block' do
    get "/#{locale}/exchange/offers"
    expect_html_content('Blocked person offer')
  end
end
