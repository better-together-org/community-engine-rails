# frozen_string_literal: true

module BetterTogether
  # Hourly scan job that enqueues a pull job for each active PersonAccessGrant
  # eligible for linked-content sync, passing the per-grant cursor so each
  # pull resumes from where it left off rather than restarting from page 1.
  class FederatedLinkedSeedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform
      eligible_grants.each do |grant|
        ::BetterTogether::FederatedLinkedSeedPullJob.perform_later(
          platform_connection_id: grant.person_link.platform_connection_id,
          recipient_person_id: grant.grantee_person_id,
          person_access_grant_id: grant.id,
          sync_cursor: grant.sync_cursor
        )
      end
    end

    private

    def eligible_grants # rubocop:todo Metrics/MethodLength
      ::BetterTogether::PersonAccessGrant.current_active
                                         .joins(person_link: :platform_connection)
                                         .includes(:grantee_person, person_link: :platform_connection)
                                         .where.not(grantee_person_id: nil)
                                         .where(
                                           better_together_platform_connections: {
                                             status: ::BetterTogether::PlatformConnection::STATUS_VALUES[:active]
                                           }
                                         )
                                         .where(
                                           "better_together_platform_connections.settings->>'federation_auth_policy' " \
                                           'IN (?)',
                                           %w[api_read api_write]
                                         )
                                         .where(
                                           "better_together_platform_connections.settings->>'allow_content_read_scope' " \
                                           "= 'true'"
                                         )
                                         .where(
                                           "better_together_platform_connections.settings->>'allow_linked_content_read_scope' " \
                                           "= 'true'"
                                         )
                                         .where(
                                           "better_together_platform_connections.settings->>'last_sync_status' != ?",
                                           'running'
                                         )
    end
  end
end
