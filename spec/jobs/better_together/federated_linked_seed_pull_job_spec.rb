# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedLinkedSeedPullJob, type: :job do
  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:recipient_person) { create(:better_together_person) }
    let(:pull_result) do
      BetterTogether::FederatedLinkedSeedPullService::Result.new(
        connection:,
        recipient_identifier: recipient_person.identifier,
        seeds: [{ 'better_together' => { 'seed' => { 'origin' => { 'lane' => 'private_linked' } }, 'payload' => { 'type' => 'post', 'id' => SecureRandom.uuid } } }],
        next_cursor: 'private-cursor-2'
      )
    end

    it 'pulls linked seeds and ingests them for the recipient' do
      allow(BetterTogether::FederatedLinkedSeedPullService).to receive(:call).and_return(pull_result)
      allow(BetterTogether::Seeds::LinkedSeedIngestService).to receive(:call)

      described_class.perform_now(platform_connection_id: connection.id, recipient_person_id: recipient_person.id, sync_cursor: 'private-cursor-1')

      expect(BetterTogether::FederatedLinkedSeedPullService).to have_received(:call).with(
        connection:,
        recipient_identifier: recipient_person.identifier,
        cursor: 'private-cursor-1'
      )
      expect(BetterTogether::Seeds::LinkedSeedIngestService).to have_received(:call).with(
        connection:,
        recipient_person: recipient_person,
        seeds: pull_result.seeds
      )
    end
  end
end
