# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # rubocop:todo Metrics/ModuleLength
  RSpec.describe Event do
    subject(:event) { build(:event) }

    describe 'associations' do
      it { is_expected.to have_one(:location).class_name('Geography::LocatableLocation') }
      it { is_expected.to accept_nested_attributes_for(:location) }
      it { is_expected.to have_many(:event_attendances).dependent(:destroy) }
      it { is_expected.to have_many(:attendees).through(:event_attendances).source(:person) }
    end

    describe 'validations' do
      it { is_expected.to validate_presence_of(:name) }

      describe 'registration_url validation' do
        it 'allows blank URLs' do
          event.registration_url = ''
          expect(event).to be_valid
        end

        it 'allows valid http/https URLs' do
          event.registration_url = 'https://example.org/register'
          expect(event).to be_valid
        end

        it 'rejects invalid URLs' do
          event.registration_url = 'not-a-url'
          expect(event).not_to be_valid
        end
      end

      context 'when ends_at is present' do
        it 'is valid when ends_at is after starts_at' do
          event.starts_at = 1.hour.from_now
          event.ends_at = 2.hours.from_now
          expect(event).to be_valid
        end

        it 'requires ends_at to be after starts_at' do
          event.starts_at = 2.hours.from_now
          event.ends_at = 1.hour.from_now
          expect(event).not_to be_valid
        end
      end
    end

    describe 'scopes' do
      describe '.past' do
        it 'returns events that have started' do
          past_event = create(:event, starts_at: 1.day.ago)
          _upcoming_event = create(:event, starts_at: 1.day.from_now)
          expect(described_class.past).to include(past_event)
        end
      end

      describe '.draft' do
        it 'returns events without starts_at' do
          draft_event = create(:event, :draft)
          _scheduled_event = create(:event, :upcoming)
          expect(described_class.draft).to include(draft_event)
        end
      end

      describe '.scheduled' do
        it 'returns events with starts_at' do
          scheduled_event = create(:event, :upcoming)
          _draft_event = create(:event, :draft)
          expect(described_class.scheduled).to include(scheduled_event)
        end
      end

      describe '.upcoming' do
        it 'returns events starting in the future' do
          upcoming_event = create(:event, :upcoming)
          _past_event = create(:event, :past)
          expect(described_class.upcoming).to include(upcoming_event)
        end
      end
    end

    describe 'callbacks' do
      let(:draft_event) { build(:event, :draft) }

      describe '#schedule_reminder_notifications' do
        it 'enqueues reminder job when conditions are met' do
          event = create(:event, :upcoming)
          create(:event_attendance, event: event)

          expect { event.send(:schedule_reminder_notifications) }.to have_enqueued_job(BetterTogether::EventReminderSchedulerJob)
        end

        it 'schedules reminder job after starts_at update' do
          event_with_attendees = create(:event, :upcoming, :with_attendees)
          expect do
            # Update ends_at to maintain validation, this should trigger both callbacks
            event_with_attendees.update!(ends_at: event_with_attendees.starts_at + 3.hours)
          end.to have_enqueued_job(BetterTogether::EventReminderSchedulerJob)
        end

        it 'does not schedule for draft events' do
          expect { draft_event.save! }.not_to have_enqueued_job(BetterTogether::EventReminderSchedulerJob)
        end
      end

      describe '#send_update_notifications' do
        it 'enqueues notification job when conditions are met' do
          event = create(:event, :upcoming)
          create(:event_attendance, event: event)

          # Mock significant changes for the test
          allow(event).to receive(:significant_changes_for_notifications).and_return(['name'])

          expect { event.send(:send_update_notifications) }.to have_enqueued_job(Noticed::EventJob)
        end

        it 'does not notify when no attendees' do
          event = create(:event, :upcoming)

          expect { event.send(:send_update_notifications) }.not_to have_enqueued_job(Noticed::EventJob)
        end
      end
    end

    describe 'instance methods' do
      let(:draft_event) { build(:event, :draft) }
      let(:scheduled_event) { build(:event, :upcoming) }
      let(:upcoming_event) { build(:event, :upcoming) }
      let(:past_event) { build(:event, :past) }

      describe '#draft?' do
        it 'returns true when starts_at is nil' do
          expect(draft_event).to be_draft
        end

        it 'returns false when starts_at is present' do
          expect(scheduled_event).not_to be_draft
        end
      end

      describe '#scheduled?' do
        it 'returns true when starts_at is present' do
          expect(scheduled_event).to be_scheduled
        end

        it 'returns false when starts_at is nil' do
          expect(draft_event).not_to be_scheduled
        end
      end

      describe '#upcoming?' do
        it 'returns true for future events' do
          expect(upcoming_event).to be_upcoming
        end

        it 'returns false for past events' do
          expect(past_event).not_to be_upcoming
        end

        it 'returns false for draft events' do
          expect(draft_event).not_to be_upcoming
        end
      end

      describe '#past?' do
        it 'returns true for past events' do
          expect(past_event).to be_past
        end

        it 'returns false for upcoming events' do
          expect(upcoming_event).not_to be_past
        end

        it 'returns false for draft events' do
          expect(draft_event).not_to be_past
        end
      end

      describe '#duration_in_hours' do
        context 'when both starts_at and ends_at are present' do
          let(:timed_event) { build(:event, starts_at: Time.current, ends_at: Time.current + 4.5.hours) }

          it 'calculates duration in hours' do
            expect(timed_event.duration_in_hours).to be_within(0.01).of(4.5)
          end
        end

        context 'when ends_at is not present' do
          let(:open_ended_event) { build(:event, starts_at: Time.current, ends_at: nil) }

          it 'returns nil' do
            expect(open_ended_event.duration_in_hours).to be_nil
          end
        end
      end

      describe '#location?' do
        it 'returns true when location is present' do
          event_with_location = build(:event, :with_simple_location)
          expect(event_with_location.location?).to be true
        end

        it 'returns false when location is not present' do
          event_without_location = build(:event)
          expect(event_without_location.location?).to be false
        end
      end

      describe '#requires_reminder_scheduling?' do
        let(:event_with_attendees) { create(:event, :upcoming, :with_attendees) }

        it 'returns true for upcoming events with attendees' do
          expect(event_with_attendees.requires_reminder_scheduling?).to be true
        end

        it 'returns false for draft events' do
          expect(draft_event.requires_reminder_scheduling?).to be false
        end

        it 'returns false for events without attendees' do
          expect(upcoming_event.requires_reminder_scheduling?).to be false
        end
      end

      describe '#significant_changes_for_notifications' do
        let(:event) { create(:event) }

        it 'detects significant attributes in list' do
          event.name = 'New Name'
          event.save

          # Call the method during a simulated callback context
          allow(event).to receive(:saved_changes).and_return({ 'name_en' => ['Old Name', 'New Name'] })
          expect(event.significant_changes_for_notifications).to include('name_en')
        end

        it 'excludes non-significant changes' do
          allow(event).to receive(:saved_changes).and_return({ 'created_at' => [1.hour.ago, Time.current] })
          expect(event.significant_changes_for_notifications).to be_empty
        end
      end

      describe '#host_community' do
        let(:event) { build(:event) }

        context 'when host community exists' do # rubocop:todo RSpec/MultipleMemoizedHelpers
          let!(:host_community) { create(:community, :host) }

          it 'returns the host community' do
            expect(event.host_community).to eq(host_community)
          end

          it 'caches the host community' do # rubocop:todo RSpec/MultipleExpectations
            allow(BetterTogether::Community).to receive(:host).and_call_original
            expect(event.host_community).to eq(host_community)
            event.host_community
            expect(BetterTogether::Community).to have_received(:host).once
          end
        end

        context 'when no host community exists' do
          it 'returns nil when no host community exists' do
            expect(event.host_community).to be_nil
          end
        end
      end

    it 'defaults its host to its creator' do
      expect(event.event_hosts.map(&:host)).to include(event.creator)
    end

    describe 'delegation' do
      it 'delegates location_geocoding_string to location' do
        expect(event).to respond_to(:location_geocoding_string)
      end

      it 'delegates location_display_name to location' do
        expect(event).to respond_to(:location_display_name)
      end

      context 'when location is not present' do
        it 'returns nil for location_display_name' do
          expect(event.location_display_name).to be_nil
        end

        it 'returns nil for location_geocoding_string' do
          expect(event.location_geocoding_string).to be_nil
        end
      end
    end

    describe 'class methods' do
      describe '.permitted_attributes' do
        it 'includes standard attributes' do
          expected_attrs = %i[
            name description starts_at ends_at registration_url
          ]
          expect(described_class.permitted_attributes.flatten).to include(*expected_attrs)
        end

        it 'includes nested location attributes' do # rubocop:todo RSpec/MultipleExpectations
          permitted_attrs = described_class.permitted_attributes.flatten
          location_hash = permitted_attrs.find { |attr| attr.is_a?(Hash) && attr.key?(:location_attributes) }
          expect(location_hash).to be_present
          expect(location_hash[:location_attributes]).to include(:creator_id, :name, :locatable_id, :locatable_type)
        end
      end
    end
  end
end
