# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  module Billing
    RSpec.describe Event do
      include_context 'with clean billing processors'

      let!(:host_platform) { configure_host_platform }

      it_behaves_like 'a platform-bound billing record' do
        def build_record(platform:) = build(:better_together_billing_event, platform:)
      end

      it_behaves_like 'encrypts sensitive billing fields' do
        let(:saved_record) { create(:better_together_billing_event, **encrypted_fields) }
        let(:encrypted_fields) do
          { payload: { 'id' => 'evt_1', 'type' => 'x', 'customer_email' => 'private.person@example.test' },
            error_message: 'card ending 4242 was declined' }
        end
      end

      it 'requires a snake_case processor, event type and a unique id per processor' do
        create(:better_together_billing_event, processor: 'fake', event_id: 'evt_1')

        expect(build(:better_together_billing_event, processor: 'Fake Co')).not_to be_valid
        expect(build(:better_together_billing_event, processor: 'fake', event_id: 'evt_1')).not_to be_valid
        expect(build(:better_together_billing_event, processor: 'other', event_id: 'evt_1')).to be_valid
      end

      describe 'subject' do
        let(:subject_platform) { create(:better_together_platform) }

        it 'accepts only registered subject types' do
          expect(Subjectable.model_names).to include('BetterTogether::Platform')
          expect(build(:better_together_billing_event, subject: subject_platform)).to be_valid

          Subjectable.model_names.delete('BetterTogether::Platform')
          expect(build(:better_together_billing_event, subject: subject_platform)).not_to be_valid
        ensure
          Subjectable.model_names << 'BetterTogether::Platform'
        end

        it 'finds the events about a record' do
          about = create(:better_together_billing_event, subject: subject_platform)
          create(:better_together_billing_event)

          expect(described_class.about(subject_platform)).to contain_exactly(about)
        end

        it 'does not re-check the subject type when something else changes' do
          event = create(:better_together_billing_event, subject: subject_platform)
          Subjectable.model_names.delete('BetterTogether::Platform')

          expect { event.dead_letter!(reason: 'stale_unresolved_drift') }.not_to raise_error
        ensure
          Subjectable.model_names << 'BetterTogether::Platform'
        end

        it 'is optional' do
          expect(build(:better_together_billing_event, subject: nil)).to be_valid
        end
      end

      describe 'outcome_kind' do
        it 'accepts the shared vocabulary or nothing, and nothing else' do
          EventResult::OUTCOME_KINDS.each { |kind| expect(build(:better_together_billing_event, outcome_kind: kind.to_s)).to be_valid }
          expect(build(:better_together_billing_event, outcome_kind: nil)).to be_valid
          expect(build(:better_together_billing_event, outcome_kind: 'stripe_invoice_paid')).not_to be_valid
        end
      end

      describe 'owners' do
        let(:community) { create(:better_together_community) }

        it 'accepts only registered billable owner types' do
          Billable.model_names << 'BetterTogether::Community'

          expect(build(:better_together_billing_event, billable_owner: community)).to be_valid
          Billable.model_names.delete('BetterTogether::Community')
          expect(build(:better_together_billing_event, billable_owner: community)).not_to be_valid
        end

        it 'does not re-check owner types when something else about the event changes' do
          Billable.model_names << 'BetterTogether::Community'
          event = create(:better_together_billing_event, billable_owner: community)
          Billable.model_names.delete('BetterTogether::Community')

          expect { event.dead_letter!(reason: 'stale_unresolved_drift') }.not_to raise_error
          expect { event.redact_payload! }.not_to raise_error
        end

        it 'refuses an owner that is bound to another platform' do
          Billable.model_names << 'BetterTogether::Community'
          other = create(:better_together_platform)
          community.define_singleton_method(:billing_bound_platform_id) { other.id }

          event = build(:better_together_billing_event, billable_owner: community)

          expect(event).not_to be_valid
          expect(event.errors.details[:platform]).to include(a_hash_including(error: :platform_owner_mismatch))
        ensure
          Billable.model_names.delete('BetterTogether::Community')
        end
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

      describe '.operator_alert_summary' do
        it 'dates the oldest unresolved event by when it last ran, or when it arrived if it never ran' do
          never_ran = create(:better_together_billing_event, processing_status: 'failed', created_at: 10.hours.ago, last_attempted_at: nil)
          create(:better_together_billing_event, processing_status: 'failed', created_at: 9.hours.ago, last_attempted_at: 8.hours.ago)

          summary = described_class.operator_alert_summary

          expect(summary[:unresolved_count]).to eq(2)
          expect(summary[:oldest_unresolved_at]).to be_within(1.second).of(never_ran.created_at)
        end
      end

      describe '#redact_payload!' do
        let(:payload) { { 'id' => 'evt_9', 'type' => 'x', 'customer_email' => 'a@example.test' } }

        it 'uses the processor adapter sanitizer' do
          Billing.register_processor(:fake, -> { FakeAdapter.new })
          event = create(:better_together_billing_event, payload:)

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
          expect(event.payload_redacted_at).to be_present
        end

        it 'fails closed to id and type when no adapter is installed' do
          event = create(:better_together_billing_event, payload:)

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
        end

        it 'fails closed to id and type when the adapter cannot be built or its sanitizer raises' do
          Billing.register_processor(:fake, -> { raise 'boom' })
          event = create(:better_together_billing_event, payload:)
          allow(Rails.logger).to receive(:error)

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
          expect(Rails.logger).to have_received(:error).with(/sanitizer failed/)
        end

        it 'fails closed when a sanitizer hands back something that is not a Hash' do
          adapter = FakeAdapter.new
          allow(adapter).to receive(:sanitize_payload).and_return('everything')
          Billing.register_processor(:fake, -> { adapter })
          event = create(:better_together_billing_event, payload:)

          event.redact_payload!

          expect(event.reload.payload).to eq('id' => 'evt_9', 'type' => 'x')
        end
      end

      describe '#dead_letter_if_stale!' do
        it 'dead-letters an event that is still stuck, with the right reason' do
          event = create(:better_together_billing_event, processing_status: 'failed', attempt_count: described_class::MAX_ATTEMPTS,
                                                         last_attempted_at: 1.minute.ago)

          expect(event.dead_letter_if_stale!).to be(true)
          expect(event.reload).to have_attributes(processing_status: 'dead_lettered', dead_letter_reason: 'retries_exhausted')
        end

        it 'leaves an event alone that a job finished after the sweep selected it' do
          event = create(:better_together_billing_event, processing_status: 'failed', attempt_count: described_class::MAX_ATTEMPTS,
                                                         last_attempted_at: 1.minute.ago)
          sweep_copy = described_class.find(event.id)
          event.update!(processing_status: 'processed', processed_at: Time.current)

          expect(sweep_copy.dead_letter_if_stale!).to be(false)
          expect(event.reload.processing_status).to eq('processed')
        end
      end

      describe 'states' do
        it 'is replayable only while the payload is intact' do
          event = create(:better_together_billing_event)
          expect(event.replayable_payload?).to be true

          event.update!(payload_redacted_at: Time.current)
          expect(event.replayable_payload?).to be false
        end

        it 'knows when its outcome is final and when a job holds it' do
          expect(build(:better_together_billing_event, processing_status: 'processed')).to be_terminal
          expect(build(:better_together_billing_event, processing_status: 'failed')).not_to be_terminal
          expect(build(:better_together_billing_event, claimed_at: 1.minute.ago)).to be_claimed
          expect(build(:better_together_billing_event, claimed_at: 1.hour.ago)).not_to be_claimed
        end

        it 'starts a replay from a clean slate' do
          event = create(:better_together_billing_event, processing_status: 'dead_lettered', attempt_count: 5, claimed_at: 1.hour.ago)

          event.mark_replay_requested!(requested_by: create(:better_together_person))

          expect(event.reload).to have_attributes(processing_status: 'replayed', attempt_count: 0, claimed_at: nil, replay_count: 1)
        end
      end

      it 'truncates stored error messages' do
        expect(described_class.safe_error_message(StandardError.new('x' * 900)).length).to eq(described_class::ERROR_MESSAGE_LIMIT)
      end

      it 'is reached through its platform and cannot be exported as a seed' do
        event = create(:better_together_billing_event)

        expect(host_platform.billing_events).to include(event)
        expect(event).not_to respond_to(:export_as_seed)
      end
    end
  end
end
