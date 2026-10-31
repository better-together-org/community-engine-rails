# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::OrderClaimsController do
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  def claim_path(record = order) = better_together.billing_order_claim_path(record, locale:)
  def order_path(record = order) = better_together.billing_order_path(record, locale:)

  it 'sends a visitor to sign in' do
    post claim_path

    expect(response).to have_http_status(:found)
    expect(offline.reload.status).to eq('awaiting')
  end

  context 'when signed in as the buyer' do
    before { sign_in buyer_user }

    it 'tells the seller they sent it, with a note, and shows that on their order' do
      offline
      clear_notices
      deliver_now { post claim_path, params: { reference: 'left it in the box' } }

      expect(response).to redirect_to(order_path)
      expect(offline.reload).to have_attributes(status: 'claimed', buyer_reference: 'left it in the box')
      expect(kinds_for(steward)).to eq(['payment_claimed'])

      get order_path
      expect(response.body).to include('billing-offline-claimed-note')
    end

    it 'does nothing harmful once the seller has confirmed' do
      transition.receive(offline, by: steward)

      post claim_path, params: { reference: 'late' }

      expect(response).to redirect_to(order_path)
      expect(offline.reload).to have_attributes(status: 'confirmed', buyer_reference: nil)
    end

    it 'is limited, and says so' do
      BetterTogether::Billing::OfflinePayments::Transition::CLAIM_LIMIT.times { post claim_path }
      post claim_path

      expect(flash[:alert]).to eq(I18n.t('better_together.billing.offline_payments.too_many_claims'))
    end

    it 'cuts a very long note short rather than failing' do
      post claim_path, params: { reference: 'x' * 1000 }

      expect(offline.reload.buyer_reference.length).to eq(BetterTogether::Billing::OfflinePayment::REFERENCE_LIMIT)
    end

    it 'is a 404 for another buyer\'s order' do
      theirs = place_offline('cash', buyer: other_buyer)

      post claim_path(theirs)

      expect(response).to have_http_status(:not_found)
      expect(offline_for(theirs).reload.status).to eq('awaiting')
    end

    it 'is a 404 for an order with nothing to pay outside the platform' do
      plain = place_order(payment_method: 'fake')

      post claim_path(plain)

      expect(response).to have_http_status(:not_found)
    end
  end

  context 'when signed in as someone else' do
    it 'is a 404' do
      sign_in other_buyer_user

      post claim_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
