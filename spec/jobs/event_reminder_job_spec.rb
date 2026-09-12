# frozen_string_literal: true

require 'rails_helper'

# Specs for event reminder job classes.
module BetterTogether # :nodoc:
  RSpec.describe EventReminderJob do
    include ActiveJob::TestHelper

    subject(:job) { described_class.new }

    let(:event) { create(:event, :upcoming) }
    let(:recipient) { create(:person) }

    before do
      create(:event_attendance, event:, person: recipient, status: 'going')
    end

    describe '#perform' do
      it 'delivers event reminder notifications to attendees' do
        expect(BetterTogether::EventReminderNotifier)
          .to receive(:with)
          .with(record: event, reminder_type: '24_hours')
          .and_call_original

        perform_enqueued_jobs do
          job.perform(event.id, '24_hours')
        end
      end

      context 'when event does not exist' do
        it 'completes without sending notifications' do
          expect do
            job.perform(999_999)
          end.not_to have_enqueued_job(Noticed::EventJob)
        end
      end

      context 'when event has no attendees' do
        let(:event_without_attendees) { create(:event, :upcoming) }

        it 'completes without sending notifications' do
          expect do
            job.perform(event_without_attendees.id)
          end.not_to have_enqueued_job(Noticed::EventJob)
        end
      end

      context 'when event is in the past' do
        let(:past_event) { create(:event, :past, :with_attendees) }

        it 'does not send notifications (reminders only for future events)' do
          expect do
            job.perform(past_event.id)
          end.not_to have_enqueued_job(Noticed::EventJob)
        end
      end

      context 'when the reminder has already been sent' do
        let(:scheduled_for) { (event.local_starts_at - 1.hour).iso8601 }

        it 'does not create duplicate notifications for the same reminder bucket' do
          perform_enqueued_jobs do
            BetterTogether::EventReminderNotifier.with(record: event, reminder_type: '1_hour').deliver(recipient)
          end

          expect(BetterTogether::EventReminderNotifier).not_to receive(:with)

          perform_enqueued_jobs do
            job.perform(event.id, '1_hour', scheduled_for)
          end
        end
      end

      context 'when the event schedule has changed since the reminder was queued' do
        it 'skips stale scheduled reminders' do
          stale_schedule = (event.local_starts_at - 1.hour).iso8601
          event.update!(starts_at: event.starts_at + 2.hours, ends_at: event.ends_at + 2.hours)

          expect(BetterTogether::EventReminderNotifier).not_to receive(:with)

          perform_enqueued_jobs do
            job.perform(event.id, '1_hour', stale_schedule)
          end
        end
      end
    end

    describe 'queue and retry configuration' do
      it 'uses the notifications queue' do
        expect(described_class.queue_name).to eq('notifications')
      end

      it 'has retry configuration' do
        expect(described_class).to respond_to(:retry_on)
      end

      it 'has discard configuration for non-retryable errors' do
        expect(described_class).to respond_to(:discard_on)
      end
    end

    describe 'job scheduling' do
      it 'can be enqueued for future execution' do
        future_time = 1.hour.from_now

        expect do
          described_class.set(wait_until: future_time).perform_later(event.id, 'start_time', future_time.iso8601)
        end.to have_enqueued_job(described_class).with(event.id, 'start_time', future_time.iso8601).on_queue('notifications')
      end
    end
  end
end
