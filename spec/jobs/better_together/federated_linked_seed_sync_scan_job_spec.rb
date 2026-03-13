# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::FederatedLinkedSeedSyncScanJob do
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

    it 'enqueues linked-seed pull jobs only for grants on linked-content-enabled connections' do
      expect do
        described_class.perform_now
      end.to have_enqueued_job(BetterTogether::FederatedLinkedSeedPullJob)
        .with(
          hash_including(
            platform_connection_id: eligible_grant.person_link.platform_connection_id,
            recipient_person_id: eligible_grant.grantee_person_id
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
  end
end
