# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe FederatedEventMirrorService do
    describe '#call' do
      let(:source_platform) { create(:better_together_platform, :community_engine_peer) }
      let(:target_platform) { create(:better_together_platform) }
      let(:connection) do
        create(
          :better_together_platform_connection,
          :active,
          source_platform:,
          target_platform:,
          content_sharing_policy: 'mirror_network_feed',
          share_events: true
        )
      end
      let(:remote_attributes) do
        {
          name: 'Remote Event',
          description: 'Remote event description',
          identifier: 'remote-event',
          privacy: 'public',
          starts_at: 2.days.from_now,
          ends_at: 2.days.from_now + 90.minutes,
          duration_minutes: 90,
          timezone: 'America/St_Johns'
        }
      end

      it 'preserves the remote UUID for CE-compatible sources' do
        remote_id = SecureRandom.uuid

        event = described_class.new(
          connection:,
          remote_attributes:,
          remote_id:,
          preserve_remote_uuid: true
        ).call

        expect(event.id).to eq(remote_id)
        expect(event.platform).to eq(source_platform)
        expect(event.source_id).to be_nil
        expect(event.last_synced_at).to be_present
        expect(event.event_hosts.map(&:host)).to include(source_platform)
      end

      it 'falls back to source_id for non-UUID remote identifiers' do
        event = described_class.new(
          connection:,
          remote_attributes:,
          remote_id: 'legacy-event-42',
          preserve_remote_uuid: false
        ).call

        expect(event.id).not_to eq('legacy-event-42')
        expect(event.source_id).to eq('legacy-event-42')
        expect(event.platform).to eq(source_platform)
        expect(event.event_hosts.map(&:host)).to include(source_platform)
      end

      it 'updates an existing mirrored event on repeat import' do
        existing = described_class.new(
          connection:,
          remote_attributes:,
          remote_id: 'legacy-event-42'
        ).call

        updated = described_class.new(
          connection:,
          remote_attributes: remote_attributes.merge(name: 'Updated Remote Event'),
          remote_id: 'legacy-event-42'
        ).call

        expect(updated.id).to eq(existing.id)
        expect(updated.name).to eq('Updated Remote Event')
      end

      it 'falls back to UTC for invalid timezones' do
        event = described_class.new(
          connection:,
          remote_attributes: remote_attributes.merge(timezone: 'Not/A_Timezone'),
          remote_id: 'legacy-event-99'
        ).call

        expect(event.timezone).to eq('UTC')
      end

      it 'rejects mirroring when the connection policy does not allow events' do
        connection.update!(content_sharing_policy: 'none')

        expect do
          described_class.new(
            connection:,
            remote_attributes:,
            remote_id: SecureRandom.uuid,
            preserve_remote_uuid: true
          ).call
        end.to raise_error(ArgumentError, /not authorized/)
      end
    end
  end
end
