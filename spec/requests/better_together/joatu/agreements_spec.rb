# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Agreements', :as_user do
  let(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }
  let(:offer) { create(:joatu_offer) }
  let(:request_record) { create(:joatu_request, creator: person) }
  let(:valid_attributes) { { offer_id: offer.id, request_id: request_record.id, terms: 'terms', value: 'value' } }
  let(:agreement) { create(:joatu_agreement, offer: offer, request: request_record) }

  describe 'routing' do
    it 'routes to #index' do
      get "/#{I18n.locale}/exchange/agreements"
      expect(response).to have_http_status(:ok) # or whatever is appropriate
    end
  end

  describe 'GET /index' do
    it 'returns success without contribution and evidence summaries' do
      create(:claim, claimable: agreement, statement: 'Agreements can expose evidence on list views.')
      create(:citation, citeable: agreement, reference_key: 'joatu_agreement_summary', title: 'JOATU Agreement Summary')

      get better_together.joatu_agreements_path(locale: I18n.locale)
      expect(response).to be_successful
      expect(response.body).not_to include('Contributors:')
      expect(response.body).not_to include('Evidence:')
      expect(response.body).not_to include('Governance Bundle')
    end
  end

  describe 'POST /create' do
    it 'creates an agreement' do
      expect do
        post better_together.joatu_agreements_path(locale: I18n.locale), params: { joatu_agreement: valid_attributes }
      end.to change(BetterTogether::Joatu::Agreement, :count).by(1)
    end
  end

  describe 'GET /show' do
    it 'returns success without contribution and evidence references' do
      citation = create(:citation, citeable: agreement, title: 'JOATU Agreement Notes', reference_key: 'joatu-agreement-notes')
      claim = create(:claim, claimable: agreement, statement: 'This agreement is backed by review notes.')
      create(:evidence_link, claim:, citation:, relation_type: 'supports')

      get better_together.joatu_agreement_path(agreement, locale: I18n.locale)
      expect(response).to be_successful
      expect(response.body).not_to include('Contributors:')
      expect(response.body).not_to include('Claims and Supporting Evidence')
      expect(response.body).not_to include('Evidence and Citations')
      expect(response.body).not_to include('JOATU Agreement Notes')
    end
  end

  describe 'PATCH /update' do
    # rubocop:todo RSpec/MultipleExpectations
    it 'updates the agreement' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      patch better_together.joatu_agreement_path(agreement, locale: I18n.locale),
            params: { joatu_agreement: { status: 'accepted' } }
      expect(response).to redirect_to(
        better_together.edit_joatu_agreement_path(agreement, locale: I18n.locale)
      )
      expect(agreement.reload.status).to eq('accepted')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the agreement' do
      to_delete = create(:joatu_agreement, offer: offer, request: request_record)
      expect do
        delete better_together.joatu_agreement_path(to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Agreement, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
