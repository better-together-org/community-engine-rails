# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedLinkedSeedSyncScanJob do
  include ActiveJob::TestHelper

  subject(:job) { described_class.new }

  describe 'queueing' do
    it 'uses the platform_sync queue' do
      expect(described_class.new.queue_name).to eq('platform_sync')
    end
  end

  describe '#perform' do
    let!(:eligible_grant) do
      create(
        :better_together_person_access_grant,
        person_link: create(
          :better_together_person_link,
          platform_connection: create(
            :better_together_platform_connection,
            :active,
            federation_auth_policy: 'api_read',
            allow_content_read_scope: true,
            allow_linked_content_read_scope: true
          )
        ),
        allow_private_posts: true
      )
    end

    let!(:ineligible_grant) do
      create(
        :better_together_person_access_grant,
        person_link: create(
          :better_together_person_link,
          platform_connection: create(
            :better_together_platform_connection,
            :active,
            federation_auth_policy: 'api_read',
            allow_content_read_scope: true,
            allow_linked_content_read_scope: false
          )
        ),
        allow_private_posts: true
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
      clear_enqueued_jobs
      allow(Sidekiq).to receive(:redis).and_yield(fake_redis)
    end

    it 'enqueues linked-seed pull jobs only for grants on linked-content-enabled connections' do
      expect do
        job.perform
      end.to have_enqueued_job(BetterTogether::FederatedLinkedSeedPullJob)
        .with(
          hash_including(
            platform_connection_id: eligible_grant.person_link.platform_connection_id,
            recipient_person_id: eligible_grant.grantee_person_id,
            person_access_grant_id: eligible_grant.id
          )
        )
        .on_queue('platform_sync')

      matching_jobs = ActiveJob::Base.queue_adapter.enqueued_jobs.select do |job|
        job[:job] == BetterTogether::FederatedLinkedSeedPullJob
      end
      expect(
        matching_jobs.any? do |job|
          job[:args].first['platform_connection_id'] == ineligible_grant.person_link.platform_connection_id
        end
      ).to be(false)
    end

    it 'skips grants whose dispatch lock is already held' do
      fake_redis.set(job.send(:dispatch_lock_key, eligible_grant.id), 'existing-owner', nx: true, ex: 600)

      job.perform

      expect(BetterTogether::FederatedLinkedSeedPullJob).not_to have_been_enqueued
    end

    it 'releases the dispatch lock if enqueueing raises' do
      allow(BetterTogether::FederatedLinkedSeedPullJob).to receive(:perform_later).and_raise(StandardError, 'queue unavailable')

      expect { job.perform }.to raise_error(StandardError, 'queue unavailable')
      expect(fake_redis.value_for(job.send(:dispatch_lock_key, eligible_grant.id))).to be_nil
    end
  end
end
