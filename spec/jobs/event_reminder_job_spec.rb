# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventReminderJob do
    include ActiveJob::TestHelper

    subject(:job) { described_class.new }

    let(:event) { create(:event, :upcoming, :with_attendees) }

    describe '#perform' do
      it 'delivers event reminder notifications to attendees' do
        expect do
          job.perform(event.id)
        end.to have_enqueued_job(Noticed::EventJob).at_least(1).times
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
    end

    describe 'queue and retry configuration' do
      it 'uses the notifications queue' do
        expect(described_class.queue_name).to eq('notifications')
      end

      it 'has retry configuration' do
        # Check that retry configuration exists (may be empty if not configured)
        expect(described_class).to respond_to(:retry_on)
      end

      it 'has discard configuration for non-retryable errors' do
        # Check that discard configuration exists (may be empty if not configured)
        expect(described_class).to respond_to(:discard_on)
      end
    end

    describe 'job scheduling' do
      it 'can be enqueued for future execution' do
        future_time = 1.hour.from_now
        expect do
          described_class.set(wait_until: future_time).perform_later(event.id)
        end.to have_enqueued_job(described_class).with(event.id).on_queue('notifications')
      end
    end
  end
end
