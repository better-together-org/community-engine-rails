# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe EventReminderSchedulerJob do
    include ActiveJob::TestHelper

    subject(:job) { described_class.new }

    let(:event) { create(:event, :upcoming, :with_attendees) }

    describe '#perform' do
      before do
        clear_enqueued_jobs
        Rails.cache.clear
      end

      it 'schedules reminder notifications at appropriate intervals' do
        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued.exactly(3).times
      end

      it 'schedules 24-hour reminder' do
        reminder_time = event.local_starts_at - 24.hours

        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id, '24_hours', reminder_time.iso8601)
          .at(reminder_time)
      end

      it 'schedules 1-hour reminder' do
        reminder_time = event.local_starts_at - 1.hour

        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id, '1_hour', reminder_time.iso8601)
          .at(reminder_time)
      end

      it 'schedules start-time reminder' do
        reminder_time = event.local_starts_at

        job.perform(event.id)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id, 'start_time', reminder_time.iso8601)
          .at(reminder_time)
      end

      context 'when event starts soon' do
        let(:soon_event) { create(:event, :with_attendees, starts_at: 30.minutes.from_now) }

        it 'only schedules future reminders' do
          reminder_time = soon_event.local_starts_at

          job.perform(soon_event.id)

          expect(EventReminderJob).to have_been_enqueued
            .with(soon_event.id, 'start_time', reminder_time.iso8601)
            .at(reminder_time)
        end

        it 'does not schedule past reminders' do
          job.perform(soon_event.id)

          expect(EventReminderJob).to have_been_enqueued.exactly(1).times
        end
      end

      context 'when event does not exist' do
        it 'completes without scheduling reminders' do
          expect do
            job.perform(999_999)
          end.not_to have_enqueued_job(EventReminderJob)
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
        let(:draft_event) { create(:event, :draft) }

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

      context 'timezone handling' do
        it 'uses event local timezone for scheduling reminders' do
          tokyo_event = create(:event, :with_attendees, timezone: 'Asia/Tokyo', starts_at: 30.hours.from_now)

          job.perform(tokyo_event.id)

          expect(EventReminderJob).to have_been_enqueued.exactly(3).times
        end

        it 'schedules reminders correctly for events in different timezones' do
          ny_event = create(:event, :with_attendees, timezone: 'America/New_York', starts_at: 30.hours.from_now)

          job.perform(ny_event.id)

          expect(EventReminderJob).to have_been_enqueued.exactly(3).times
        end

        it 'handles DST transitions correctly' do
          event_after_dst = create(
            :event,
            :with_attendees,
            timezone: 'America/New_York',
            starts_at: Time.zone.parse('2024-03-15 14:00 EDT')
          )

          job.perform(event_after_dst.id)

          expected_24h = event_after_dst.local_starts_at - 24.hours
          expect(expected_24h.hour).to eq(14)
          expect(expected_24h.day).to eq(14)
          expect(expected_24h.strftime('%Z')).to eq('EDT')
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
        expect(described_class).to respond_to(:retry_on)
      end

      it 'discards non-retryable errors' do
        expect(described_class).to respond_to(:discard_on)
      end
    end

    describe '#reminder_intervals' do
      it 'defines standard reminder intervals' do
        intervals = job.send(:reminder_intervals)

        expect(intervals).to include(24.hours, 1.hour, 0.seconds)
      end
    end

    describe '#schedule_future_reminder?' do
      let(:future_time) { 2.hours.from_now }
      let(:past_time) { 2.hours.ago }

      it 'schedules jobs for future times' do
        job.send(:schedule_future_reminder?, event, 'start_time', future_time)

        expect(EventReminderJob).to have_been_enqueued
          .with(event.id, 'start_time', future_time.iso8601)
          .at(future_time)
      end

      it 'does not schedule jobs for past times' do
        job.send(:schedule_future_reminder?, event, 'start_time', past_time)

        expect(EventReminderJob).not_to have_been_enqueued
      end

      it 'does not schedule the same reminder twice across repeated scans' do
        freeze_time do
          job.perform(event.id)

          first_pass_jobs = enqueued_jobs.select do |enqueued_job|
            enqueued_job[:job] == BetterTogether::EventReminderJob
          end

          job.perform(event.id)

          second_pass_jobs = enqueued_jobs.select do |enqueued_job|
            enqueued_job[:job] == BetterTogether::EventReminderJob
          end

          expect(second_pass_jobs).to eq(first_pass_jobs)
        end
      end
    end
  end
end
