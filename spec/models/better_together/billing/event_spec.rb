# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe Event do
      include_context 'with clean billing processors'

      it 'requires a snake_case processor, event type and a unique id per processor' do
        create(:better_together_billing_event, processor: 'fake', event_id: 'evt_1')

        expect(build(:better_together_billing_event, processor: 'Fake Co')).not_to be_valid
        expect(build(:better_together_billing_event, processor: 'fake', event_id: 'evt_1')).not_to be_valid
        expect(build(:better_together_billing_event, processor: 'other', event_id: 'evt_1')).to be_valid
      end

      it 'accepts only registered billable owner types' do
        Billable.model_names << 'BetterTogether::Community'
        community = create(:better_together_community)

        expect(build(:better_together_billing_event, billable_owner: community)).to be_valid
        Billable.model_names.delete('BetterTogether::Community')
        expect(build(:better_together_billing_event, billable_owner: community)).not_to be_valid
      end

      describe 'scopes' do
        it 'treats failed and dead-lettered as problematic, not ignored or alerted' do
          failed = create(:better_together_billing_event, processing_status: 'failed')
          dead = create(:better_together_billing_event, processing_status: 'dead_lettered')
          create(:better_together_billing_event, processing_status: 'ignored')
          create(:better_together_billing_event, processing_status: 'alerted')

          expect(described_class.problematic).to contain_exactly(failed, dead)
        end

        it 'selects stuck events for dead-lettering by exhaustion or staleness' do
          exhausted = create(:better_together_billing_event, processing_status: 'failed', attempt_count: described_class::MAX_ATTEMPTS,
                                                             last_attempted_at: 1.minute.ago)
          stale = create(:better_together_billing_event, processing_status: 'pending', last_attempted_at: 7.hours.ago)
          create(:better_together_billing_event, processing_status: 'failed', attempt_count: 2, last_attempted_at: 1.minute.ago)
          create(:better_together_billing_event, processing_status: 'processed', attempt_count: 9, last_attempted_at: 9.hours.ago)

          expect(described_class.eligible_for_dead_lettering).to contain_exactly(exhausted, stale)
        end

        it 'honours a configured payload retention window' do
          old = create(:better_together_billing_event, processed_at: 10.days.ago)
          stub_const('ENV', ENV.to_hash.merge('BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS' => '7'))

          expect(described_class.payload_retention_expired).to contain_exactly(old)
        end

        it 'ignores a non-positive retention setting' do
          stub_const('ENV', ENV.to_hash.merge('BT_BILLING_EVENT_PAYLOAD_RETENTION_DAYS' => '0'))

          expect(described_class.payload_retention_days).to eq(described_class::DEFAULT_PAYLOAD_RETENTION_DAYS)
        end
      end

      describe '#redact_payload!' do
        it 'uses the processor adapter sanitizer' do
          Billing.register_processor(:fake, -> { FakeAdapter.new })
          event = create(:better_together_billing_event, payload: { 'id' => 'evt_9', 'type' => 'x', 'customer_email' => 'a@example.test' })

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
          expect(event.payload_redacted_at).to be_present
        end

        it 'fails closed to id and type when no adapter is installed' do
          event = create(:better_together_billing_event, payload: { 'id' => 'evt_9', 'type' => 'x', 'customer_email' => 'a@example.test' })

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
        end
      end

      it 'is replayable only while the payload is intact' do
        event = create(:better_together_billing_event)
        expect(event.replayable_payload?).to be true

        event.update!(payload_redacted_at: Time.current)
        expect(event.replayable_payload?).to be false
      end

      it 'truncates stored error messages' do
        expect(described_class.safe_error_message(StandardError.new('x' * 900)).length).to eq(described_class::ERROR_MESSAGE_LIMIT)
      end
    end
  end
end
