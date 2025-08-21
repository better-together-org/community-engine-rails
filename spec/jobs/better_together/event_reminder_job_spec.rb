# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe EventReminderJob do
    include ActiveJob::TestHelper

    let(:person) { create(:person) }
    let(:event) { create(:event, :upcoming, :with_attendees) }

    describe '#perform' do
      context 'with valid event' do
        it 'sends reminders to all going attendees' do
          expect do
            described_class.perform_now(event)
          end.to change(Noticed::Notification, :count).by_at_least(1)
        end

        it 'accepts reminder type parameter' do
          expect do
            described_class.perform_now(event, '1_hour')
          end.not_to raise_error
        end
      end

      context 'with invalid event' do
        it 'handles missing event gracefully' do
          expect do
            described_class.perform_now(nil)
          end.not_to raise_error
        end

        it 'handles event without start time' do
          draft_event = create(:event, :draft)
          expect do
            described_class.perform_now(draft_event)
          end.not_to raise_error
        end
      end

      context 'when event has no attendees' do
        let(:event_without_attendees) { create(:event, :upcoming) }

        it 'completes without sending notifications' do
          expect do
            described_class.perform_now(event_without_attendees)
          end.not_to change(Noticed::Notification, :count)
        end
      end
    end

    describe 'queue configuration' do
      it 'uses the notifications queue' do
        expect(described_class.queue_name).to eq('notifications')
      end
    end

    describe 'error handling' do
      it 'handles missing events gracefully' do
        expect do
          described_class.perform_now(999_999)
        end.not_to raise_error
      end

      it 'handles invalid event IDs gracefully' do
        expect do
          described_class.perform_now(nil)
        end.not_to raise_error
      end
    end
  end
end
