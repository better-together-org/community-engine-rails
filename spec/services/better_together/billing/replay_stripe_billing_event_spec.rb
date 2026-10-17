# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ReplayStripeBillingEvent do
  include ActiveJob::TestHelper

  describe '#call' do
    let(:user) do
      find_or_create_test_user("replay-billing-event-user-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :user)
    end

    it 're-enqueues a dead-lettered Stripe event for replay' do
      billing_event = create(
        :better_together_billing_event,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        dead_letter_reason: 'repeated_failures',
        payload: {
          'id' => 'evt_replay_123',
          'type' => 'invoice.payment_failed',
          'data' => { 'object' => { 'id' => 'in_123', 'object' => 'invoice' } }
        }
      )

      expect do
        result = described_class.new.call(billing_event:, requested_by: user)
        expect(result.enqueued).to be(true)
      end.to have_enqueued_job(BetterTogether::Billing::ProcessStripeEventJob)

      expect(billing_event.reload.processing_status).to eq('replayed')
      expect(billing_event.replay_count).to eq(1)
      expect(billing_event.last_replay_requested_by_type).to eq(user.class.name)
      expect(billing_event.last_replay_requested_by_id).to eq(user.id)
    end

    it 'refuses replay when the original payload was redacted' do
      billing_event = create(
        :better_together_billing_event,
        processing_status: 'dead_lettered',
        dead_lettered_at: 1.hour.ago,
        payload_redacted_at: Time.current
      )

      result = described_class.new.call(billing_event:, requested_by: user)

      expect(result.enqueued).to be(false)
      expect(result.reason).to eq(:payload_unavailable)
    end
  end
end
