# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedLinkedSeedPullJob do
  subject(:job) { described_class.new }

  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let(:connection) { create(:better_together_platform_connection, :active) }
    let(:recipient_person) { create(:better_together_person) }
    let!(:grant) do
      create(
        :better_together_person_access_grant,
        person_link: create(
          :better_together_person_link,
          platform_connection: connection,
          source_person: create(:better_together_person),
          target_person: recipient_person
        ),
        grantee_person: recipient_person,
        allow_private_posts: true
      )
    end
    let(:pull_result) do
      BetterTogether::FederatedLinkedSeedPullService::Result.new(
        connection:,
        recipient_identifier: recipient_person.identifier,
        seeds: [{ 'better_together' => { 'seed' => { 'origin' => { 'lane' => 'private_linked' } },
                                         'payload' => { 'type' => 'post', 'id' => SecureRandom.uuid } } }],
        next_cursor: 'private-cursor-2'
      )
    end
    let(:lock_store) { {} }
    let(:fake_redis) do
      store = lock_store

      Object.new.tap do |redis|
        redis.define_singleton_method(:set) do |key, value, **options|
          return false if options[:nx] && store.key?(key)

          store[key] = { value:, ex: options[:ex] }
          true
        end

        redis.define_singleton_method(:call) do |command, _script, _key_count, key, owner|
          return 0 unless command == 'EVAL'
          return 0 unless store[key]&.fetch(:value, nil) == owner

          store.delete(key)
          1
        end

        redis.define_singleton_method(:value_for) do |key|
          store[key]&.fetch(:value, nil)
        end
      end
    end

    before do
      allow(Sidekiq).to receive(:redis).and_yield(fake_redis)
    end

    it 'pulls linked seeds and ingests them for the recipient' do
      allow(BetterTogether::FederatedLinkedSeedPullService).to receive(:call).and_return(pull_result)
      allow(BetterTogether::Seeds::LinkedSeedIngestService).to receive(:call)
      fake_redis.set(job.send(:dispatch_lock_key, grant.id), 'dispatch-token', nx: true, ex: 600)

      job.perform(platform_connection_id: connection.id, recipient_person_id: recipient_person.id,
                  sync_cursor: 'private-cursor-1', person_access_grant_id: grant.id, dispatch_lock_token: 'dispatch-token')

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
      expect(fake_redis.value_for(job.send(:dispatch_lock_key, grant.id))).to be_nil
    end

    it 'does nothing when the recipient no longer has an active linked private grant' do
      connection = create(:better_together_platform_connection, :active)
      recipient_person = create(:better_together_person)

      allow(BetterTogether::FederatedLinkedSeedPullService).to receive(:call)
      allow(BetterTogether::Seeds::LinkedSeedIngestService).to receive(:call)
      missing_grant_id = SecureRandom.uuid
      fake_redis.set(job.send(:dispatch_lock_key, missing_grant_id), 'dispatch-token', nx: true, ex: 600)

      job.perform(platform_connection_id: connection.id, recipient_person_id: recipient_person.id,
                  sync_cursor: 'private-cursor-1', person_access_grant_id: missing_grant_id, dispatch_lock_token: 'dispatch-token')

      expect(BetterTogether::FederatedLinkedSeedPullService).not_to have_received(:call)
      expect(BetterTogether::Seeds::LinkedSeedIngestService).not_to have_received(:call)
      expect(fake_redis.value_for(job.send(:dispatch_lock_key, missing_grant_id))).to be_nil
    end
  end
end
