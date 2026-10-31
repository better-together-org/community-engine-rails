# frozen_string_literal: true

require 'rails_helper'

# The buyer's own order page for a payment made outside the platform: how to pay, what to understand
# first, and the optional "I sent it".
RSpec.describe 'Paying outside the platform' do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:order) { place_offline('cash') }
  let(:offline) { offline_for(order) }

  def order_path(record = order) = better_together.billing_order_path(record, locale:)

  context 'when signed in as the buyer' do
    before { sign_in buyer_user }

    it 'shows how to pay, the amount, the hold and the disclosures, with stable ids' do
      get order_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(offline), 'billing-offline-instructions',
                                       'billing-offline-disclosure', 'billing-offline-amount', 'billing-offline-claim-form',
                                       'billing-offline-claim-reference', 'billing-offline-claim-btn')
      expect_html_contents('Hand it to Alex at the hall', I18n.t('better_together.billing.offline_payments.disclosure_outside'),
                           I18n.t('better_together.billing.offline_payments.disclosure_cash_in_person'))
    end

    it 'says the claim is optional' do
      get order_path

      expect(response.body).to include('billing-offline-claim-hint')
      expect_html_content(I18n.t('better_together.billing.offline_payments.claim_hint'))
    end

    it 'shows the cheque note for a cheque' do
      get order_path(place_offline('cheque'))

      expect_html_contents(I18n.t('better_together.billing.offline_payments.disclosure_cheque_clearing'), 'Alex Seller', '4711 Harbour Road')
    end

    it 'shows the e-transfer note, and where to send it, for an e-transfer' do
      get order_path(place_offline('etransfer', purchasable: cad_plan))

      expect_html_contents(I18n.t('better_together.billing.offline_payments.disclosure_etransfer_canada'), 'alex@example.test')
    end

    it 'shows the instructions as they were when the order was placed, not as they are now' do
      order
      host_platform.billing_processor_settings.find_by!(processor: 'cash').update!(settings: { 'instructions' => 'Send it to someone else' })

      get order_path

      expect_html_content('Hand it to Alex at the hall')
      expect_no_html_content('Send it to someone else')
    end

    it 'shows what the buyer told the seller once they have claimed' do
      transition.claim(offline, reference: 'sent')

      get order_path

      expect(response.body).to include('billing-offline-claimed-note')
    end

    it 'hides the instructions once the seller has confirmed, and says it is paid' do
      transition.receive(offline, by: steward)

      get order_path

      expect(response.body).not_to include('billing-offline-instructions')
      expect(response.body).not_to include('billing-offline-claim-form')
      expect_html_content(I18n.t('better_together.billing.offline_payments.status_message_confirmed'))
    end

    it 'says why, and still offers to tell the seller, after the hold ran out' do
      order.update!(expires_at: 1.hour.ago)
      BetterTogether::Billing::Orders::Expire.call(order)

      get order_path

      expect(response.body).not_to include('billing-offline-instructions')
      expect(response.body).to include('billing-offline-claim-form')
      expect_html_content(I18n.t('better_together.billing.offline_payments.status_message_expired'))
    end

    it 'shows the seller\'s reason when a payment was not accepted' do
      transition.reject(offline, by: steward, reason: 'nothing arrived')

      get order_path

      expect(response.body).to include('billing-offline-rejection-reason')
      expect_html_content('nothing arrived')
    end

    it 'shows nothing for an order paid another way' do
      get order_path(place_order(payment_method: 'fake'))

      expect(response.body).not_to include('billing-offline-heading')
    end
  end

  it 'never shows the instructions to anyone but the buyer' do
    order
    sign_in other_buyer_user
    get order_path
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include('Alex')

    sign_in steward_user
    get order_path
    expect(response).to have_http_status(:not_found)
  end
end
