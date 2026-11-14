# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe CleanupNotificationsJob do
    describe '#perform' do
      it 'removes notifications and events for the specified record' do
        membership = create(:better_together_person_platform_membership, status: 'active')

        # Verify a notification/event was created for this specific membership.
        # NOTE: total counts are not asserted here because the shared test database
        # is not truncated between isolated spec runs, so unrelated leftover
        # notifications may already exist. Scope lookups to this record instead.
        event = Noticed::Event.find_by(record_type: membership.class.name, record_id: membership.id)
        expect(event).to be_present
        notification = event.notifications.sole

        # Store the membership info before destroying it
        record_type = membership.class.name
        record_id = membership.id

        # Destroy the membership (this will happen before the job runs)
        membership.destroy!

        # Run the cleanup job
        expect do
          described_class.new.perform(record_type: record_type, record_id: record_id)
        end.to change(Noticed::Notification, :count).by(-1)
                                                    .and change(Noticed::Event, :count).by(-1)

        # Verify the specific records were removed
        expect(Noticed::Notification.exists?(notification.id)).to be false
        expect(Noticed::Event.exists?(event.id)).to be false
      end

      it 'handles missing records gracefully' do
        expect do
          described_class.new.perform(record_type: 'NonexistentModel', record_id: 999_999)
        end.not_to raise_error
      end

      it 'logs cleanup activities' do
        membership = create(:better_together_person_platform_membership, status: 'active')

        # Verify a notification was created for this specific membership (see note above
        # about not asserting on global counts due to non-truncated shared test DB).
        expect(Noticed::Event.exists?(record_type: membership.class.name, record_id: membership.id)).to be true

        record_type = membership.class.name
        record_id = membership.id
        membership.destroy!

        allow(Rails.logger).to receive(:info)

        described_class.new.perform(record_type: record_type, record_id: record_id)

        expect(Rails.logger).to have_received(:info).with("Cleaning up notifications for #{record_type}##{record_id}")
        expect(Rails.logger).to have_received(:info).with("Cleaned up 1 notifications and 1 events for #{record_type}##{record_id}")
      end
    end
  end
end
