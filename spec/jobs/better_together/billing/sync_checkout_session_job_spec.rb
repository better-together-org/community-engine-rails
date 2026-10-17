# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::SyncCheckoutSessionJob do
  describe '#perform' do
    let(:community) { create(:better_together_community) }
    let(:sync_result) { instance_double(BetterTogether::Billing::StripeCheckoutSessionSync::Result, synced: true) }
    let(:sync_service) { instance_double(BetterTogether::Billing::StripeCheckoutSessionSync, call: sync_result) }
    let(:broadcaster) { instance_double(BetterTogether::Billing::CheckoutSessionSyncBroadcaster, call: true) }

    before do
      allow(BetterTogether::Billing::StripeCheckoutSessionSync).to receive(:new).and_return(sync_service)
      allow(BetterTogether::Billing::CheckoutSessionSyncBroadcaster).to receive(:new).and_return(broadcaster)
    end

    it 'syncs the checkout session for the resolved owner and broadcasts the result' do
      described_class.perform_now('cs_test_123', community.class.name, community.id)

      expect(sync_service).to have_received(:call).with(checkout_session_id: 'cs_test_123', beneficiary: community)
      expect(broadcaster).to have_received(:call).with(checkout_session_id: 'cs_test_123', result: sync_result)
    end

    it 'does nothing when the owner cannot be resolved' do
      described_class.perform_now('cs_test_123', 'BetterTogether::Community', SecureRandom.uuid)

      expect(sync_service).not_to have_received(:call)
      expect(broadcaster).not_to have_received(:call)
    end

    it 'broadcasts a failure instead of retrying when Stripe rejects the session id outright' do
      error = Stripe::InvalidRequestError.new('No such checkout session', 'id')
      allow(sync_service).to receive(:call).and_raise(error)

      expect do
        described_class.perform_now('cs_bad_id', community.class.name, community.id)
      end.not_to raise_error

      expect(broadcaster).to have_received(:call).with(checkout_session_id: 'cs_bad_id', error:)
    end
  end
end
