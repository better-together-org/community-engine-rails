# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe 'BetterTogether::Joatu::Agreements', type: :request do
  routes { BetterTogether::Engine.routes }

  let(:user) { create(:user, :confirmed) }
  let(:offer) { create(:joatu_offer) }
  let(:request_record) { create(:joatu_request) }
  let(:valid_attributes) { { offer_id: offer.id, request_id: request_record.id, terms: 'terms', value: 'value' } }
  let(:agreement) { create(:joatu_agreement) }

  before { login(user) }

  describe 'routing' do
    it 'routes to #index' do
      expect(get: "/#{I18n.locale}/joatu/agreements").to route_to(
        'better_together/joatu/agreements#index',
        locale: I18n.locale.to_s
      )
    end
  end

  describe 'GET /index' do
    it 'returns success' do
      get better_together.joatu_agreements_path(locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'POST /create' do
    it 'creates an agreement' do
      expect do
        post better_together.joatu_agreements_path(locale: I18n.locale), params: { agreement: valid_attributes }
      end.to change(BetterTogether::Joatu::Agreement, :count).by(1)
    end
  end

  describe 'GET /show' do
    it 'returns success' do
      get better_together.joatu_agreement_path(agreement, locale: I18n.locale)
      expect(response).to be_successful
    end
  end

  describe 'PATCH /update' do
    it 'updates the agreement' do
      patch better_together.joatu_agreement_path(agreement, locale: I18n.locale),
            params: { agreement: { status: 'accepted' } }
      expect(response).to redirect_to(
        better_together.joatu_agreement_path(agreement, locale: I18n.locale)
      )
      expect(agreement.reload.status).to eq('accepted')
    end
  end

  describe 'DELETE /destroy' do
    it 'destroys the agreement' do
      to_delete = create(:joatu_agreement)
      expect do
        delete better_together.joatu_agreement_path(to_delete, locale: I18n.locale)
      end.to change(BetterTogether::Joatu::Agreement, :count).by(-1)
    end
  end
  # rubocop:enable Metrics/BlockLength
end
