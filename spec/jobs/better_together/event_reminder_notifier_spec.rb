# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe EventReminderNotifier do
    include ActiveJob::TestHelper

    let(:person) { create(:person) }
    let(:event) { create(:event, :upcoming, :with_attendees) }

    describe '#perform' do
      context 'with person and event' do
        it 'delivers event reminder email' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.to have_enqueued_mail(EventMailer, :event_reminder)
            .with(person, event)
        end

        it 'creates notification record' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.to change(Notification, :count).by(1)
        end

        it 'sets notification attributes correctly' do # rubocop:todo RSpec/MultipleExpectations
          described_class.perform_now(person.id, event.id)

          notification = Notification.last
          expect(notification.recipient).to eq(person)
          expect(notification.subject).to eq(event)
          expect(notification.notification_type).to eq('event_reminder')
        end
      end

      context 'when person does not exist' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            described_class.perform_now(999_999, event.id)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when event does not exist' do
        it 'raises ActiveRecord::RecordNotFound' do
          expect do
            described_class.perform_now(person.id, 999_999)
          end.to raise_error(ActiveRecord::RecordNotFound)
        end
      end

      context 'when person has email notifications disabled' do
        before do
          person.update!(email_notifications_enabled: false)
        end

        it 'creates notification record but skips email' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.to change(Notification, :count).by(1)
                                             .and not_have_enqueued_mail(EventMailer, :event_reminder)
        end
      end

      context 'when person has no email address' do
        before do
          person.update!(email: nil)
        end

        it 'creates notification record but skips email' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.to change(Notification, :count).by(1)
                                             .and not_have_enqueued_mail(EventMailer, :event_reminder)
        end
      end
    end

    describe '.notify_all_attendees' do
      let(:event_with_multiple_attendees) do
        event = create(:event, :upcoming)
        3.times { create(:event_attendance, event: event) }
        event
      end

      it 'enqueues notification jobs for all attendees' do
        expect do
          described_class.notify_all_attendees(event_with_multiple_attendees.id)
        end.to have_enqueued_job(described_class).exactly(3).times
      end

      it 'passes correct person and event IDs' do
        described_class.notify_all_attendees(event_with_multiple_attendees.id)

        event_with_multiple_attendees.attendees.each do |attendee|
          expect(described_class).to have_been_enqueued
            .with(attendee.id, event_with_multiple_attendees.id)
        end
      end

      context 'when event has no attendees' do
        let(:event_without_attendees) { create(:event, :upcoming) }

        it 'does not enqueue any jobs' do
          expect do
            described_class.notify_all_attendees(event_without_attendees.id)
          end.not_to have_enqueued_job(described_class)
        end
      end
    end

    describe 'queue configuration' do
      it 'uses the notifications queue' do
        expect(described_class.queue_name).to eq('notifications')
      end
    end

    describe 'retry and error handling' do
      it 'has retry configuration for transient errors' do
        expect(described_class.retry_on).to include(StandardError)
      end

      it 'discards non-retryable errors' do
        expect(described_class.discard_on).to include(ActiveRecord::RecordNotFound)
      end

      it 'has maximum retry attempts' do
        expect(described_class.retry_on).not_to be_empty
      end
    end

    describe 'notification delivery preferences' do
      context 'when person prefers in-app notifications only' do
        before do
          person.update!(notification_preferences: { email: false, in_app: true })
        end

        it 'creates in-app notification but skips email' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.to change(Notification, :count).by(1)
                                             .and not_have_enqueued_mail(EventMailer, :event_reminder)
        end
      end

      context 'when person has all notifications disabled' do
        before do
          person.update!(notification_preferences: { email: false, in_app: false })
        end

        it 'skips all notifications' do
          expect do
            described_class.perform_now(person.id, event.id)
          end.not_to change(Notification, :count)
            .and not_have_enqueued_mail(EventMailer, :event_reminder)
        end
      end
    end

    describe 'notification timing' do
      it 'records sent_at timestamp' do
        described_class.perform_now(person.id, event.id)

        notification = Notification.last
        expect(notification.sent_at).to be_within(1.second).of(Time.current)
      end

      it 'does not send duplicate notifications within timeframe' do # rubocop:todo RSpec/ExampleLength
        # Create existing recent notification
        create(:notification,
               recipient: person,
               subject: event,
               notification_type: 'event_reminder',
               sent_at: 1.hour.ago)

        expect do
          described_class.perform_now(person.id, event.id)
        end.not_to change(Notification, :count)
      end
    end
  end
end
