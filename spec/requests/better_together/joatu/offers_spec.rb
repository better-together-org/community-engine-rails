# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Offers', :as_user do
  let(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }
  let(:category) { create(:better_together_joatu_category) }
  let(:valid_attributes) do
    { name: 'New Offer', description: 'Offer description', creator_id: person.id, category_ids: [category.id].compact }
  end
  let(:offer) { create(:joatu_offer, creator: person) }

  describe 'routing' do
    it 'routes to #index' do
      get "/#{I18n.locale}/exchange/offers"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /index' do
    it 'returns success without contribution and evidence summaries' do
      offer.add_governed_contributor(person, role: 'reviewer')
      offer.contributions.first.update!(details: {
                                          'github_handle' => 'joatu-offer-reviewer',
                                          'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                        })
      create(:claim, claimable: offer, statement: 'Offers can carry evidence summaries in list views.')
      create(:citation, citeable: offer, reference_key: 'joatu_offer_summary', title: 'JOATU Offer Summary')

      get better_together.joatu_offers_path(locale: I18n.locale)
      expect(response).to be_successful
      expect(response.body).not_to include('Contributors:')
      expect(response.body).not_to include('GitHub-linked')
      expect(response.body).not_to include('Evidence:')
      expect(response.body).not_to include('Governance Bundle')
    end
  end

  describe 'POST /create' do
    it 'creates an offer' do
      created_offer = nil

      expect do
        post better_together.joatu_offers_path(locale: I18n.locale), params: { joatu_offer: valid_attributes }
        created_offer = BetterTogether::Joatu::Offer.order(:created_at).last
      end.to change(BetterTogether::Joatu::Offer, :count).by(1)

      expect(response).to redirect_to(
        better_together.joatu_offer_path(created_offer, locale: I18n.locale)
      )
      expect(created_offer.creator).to eq(person)
      expect(created_offer.categories).to contain_exactly(category)
    end

    it 'preserves a platform target when responding to a connection request' do
      target_platform = create(:better_together_platform, :community_engine_peer)
      connection_request = create(:better_together_joatu_connection_request, target: target_platform)

      post better_together.joatu_offers_path(locale: I18n.locale), params: {
        joatu_offer: valid_attributes.merge(
          target_type: 'BetterTogether::Platform',
          target_id: target_platform.id
        ),
        source_type: 'BetterTogether::Joatu::Request',
        source_id: connection_request.id
      }

      created_offer = BetterTogether::Joatu::Offer.order(:created_at).last
      expect(response).to redirect_to(
        better_together.joatu_offer_path(created_offer, locale: I18n.locale)
      )
      expect(created_offer.target).to eq(target_platform)
    end
  end

  describe 'GET /show' do
    it 'returns success without contribution and evidence references' do
      citation = create(:citation, citeable: offer, title: 'JOATU Offer Notes', reference_key: 'joatu-offer-notes')
      claim = create(:claim, claimable: offer, statement: 'This offer is backed by review notes.')
      create(:evidence_link, claim:, citation:, relation_type: 'supports')
      offer.add_governed_contributor(person, role: 'reviewer')
      offer.contributions.first.update!(details: {
                                          'github_handle' => 'joatu-offer-reviewer',
                                          'github_sources' => [{ 'reference_key' => 'pull_request_1494' }]
                                        })

      get better_together.joatu_offer_path(offer, locale: I18n.locale)
      expect(response).to be_successful
      expect(response.body).not_to include('Contributors:')
      expect(response.body).not_to include('GitHub-linked')
      expect(response.body).not_to include('Claims and Supporting Evidence')
      expect(response.body).not_to include('Evidence and Citations')
      expect(response.body).not_to include('JOATU Offer Notes')
    end
  end

  describe 'PATCH /update' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates the offer' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.joatu_offer_path(offer, locale: I18n.locale),
            params: { joatu_offer: { status: 'closed' } }
      expect(response).to redirect_to(
        better_together.edit_joatu_offer_path(offer, locale: I18n.locale)
      )
      expect(offer.reload.status).to eq('closed')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the offer' do
      offer_to_delete = create(:joatu_offer, creator: person)
      expect do
        delete better_together.joatu_offer_path(offer_to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Offer, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
