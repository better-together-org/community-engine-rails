# frozen_string_literal: true

module BetterTogether
  # Hourly scan job that enqueues a pull job for each active PersonAccessGrant
  # eligible for linked-content sync, passing the per-grant cursor so each
  # pull resumes from where it left off rather than restarting from page 1.
  class FederatedLinkedSeedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform
      eligible_grants.each do |grant|
        next unless grant.active_now?
        next unless grant.grantee_person_id.present?

        ::BetterTogether::FederatedLinkedSeedPullJob.perform_later(
          platform_connection_id: grant.person_link.platform_connection_id,
          recipient_person_id: grant.grantee_person_id,
          person_access_grant_id: grant.id,
          sync_cursor: grant.sync_cursor
        )
      end
    end

    private

    def eligible_grants
      ::BetterTogether::PersonAccessGrant.current_active
                                         .joins(person_link: :platform_connection)
                                         .includes(:grantee_person, person_link: :platform_connection)
                                         .where(
                                           better_together_platform_connections: {
                                             status: ::BetterTogether::PlatformConnection::STATUS_VALUES[:active],
                                             federation_auth_policy: %w[api_read api_write],
                                             allow_content_read_scope: true,
                                             allow_linked_content_read_scope: true
                                           }
                                         )
    end
  end
end
