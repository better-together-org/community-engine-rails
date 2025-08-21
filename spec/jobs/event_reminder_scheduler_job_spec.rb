# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventReminderSchedulerJob do
    include ActiveJob::TestHelper

    subject(:job) { described_class.new }

    let(:event) { create(:event, :upcoming, :with_attendees) }

    describe '#perform' do
      before do
        # Clear existing scheduled jobs
        clear_enqueued_jobs
      end

      it 'schedules reminder notifications at appropriate intervals' do
        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued.exactly(3).times
      end

      it 'schedules 24-hour reminder' do
        reminder_time = event.starts_at - 24.hours

        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id)
          .at(reminder_time)
      end

      it 'schedules 1-hour reminder' do
        reminder_time = event.starts_at - 1.hour

        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id)
          .at(reminder_time)
      end

      it 'schedules start-time reminder' do
        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id)
          .at(event.starts_at)
      end

      context 'when event starts soon' do
        let(:soon_event) { create(:event, :with_attendees, starts_at: 30.minutes.from_now) }

        it 'only schedules future reminders' do
          job.perform(soon_event.id)

          expect(EventReminderJob).to have_been_enqueued
            .with(soon_event.id)
            .at(soon_event.starts_at)
        end

        it 'does not schedule past reminders' do
          job.perform(soon_event.id)

          # Should not schedule 24-hour or 1-hour reminders for events starting in 30 minutes
          expect(EventReminderJob).to have_been_enqueued.exactly(1).times
        end
      end

      context 'when event does not exist' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            job.perform(999_999)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when event has no attendees' do
        let(:event_without_attendees) { create(:event, :upcoming) }

        it 'does not schedule any reminders' do
          job.perform(event_without_attendees.id)

          expect(EventReminderJob).not_to have_been_enqueued
        end
      end

      context 'when event is draft' do
        let(:draft_event) { create(:event, :draft, :with_attendees) }

        it 'does not schedule any reminders' do
          job.perform(draft_event.id)

          expect(EventReminderJob).not_to have_been_enqueued
        end
      end

      context 'when event is in the past' do
        let(:past_event) { create(:event, :past, :with_attendees) }

        it 'does not schedule any reminders' do
          job.perform(past_event.id)

          expect(EventReminderJob).not_to have_been_enqueued
        end
      end
    end

    describe 'queue configuration' do
      it 'uses the notifications queue' do
        expect(described_class.queue_name).to eq('notifications')
      end
    end

    describe 'retry and error handling' do
      it 'has retry configuration' do
        expect(described_class.retry_on).to include(StandardError)
      end

      it 'discards non-retryable errors' do
        expect(described_class.discard_on).to include(ActiveRecord::RecordNotFound)
      end
    end

    describe '#reminder_intervals' do
      it 'defines standard reminder intervals' do
        intervals = job.send(:reminder_intervals)

        expect(intervals).to include(24.hours, 1.hour, 0.seconds)
      end
    end

    describe '#schedule_reminder_if_future' do
      let(:future_time) { 2.hours.from_now }
      let(:past_time) { 2.hours.ago }

      it 'schedules jobs for future times' do
        job.send(:schedule_reminder_if_future, event.id, future_time)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id)
          .at(future_time)
      end

      it 'does not schedule jobs for past times' do
        job.send(:schedule_reminder_if_future, event.id, past_time)

        expect(EventReminderJob).not_to have_been_enqueued
      end
    end
  end
end
