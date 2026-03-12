# frozen_string_literal: true

module BetterTogether
  class FederatedLinkedSeedSyncScanJob < ApplicationJob
    queue_as :platform_sync

    def perform
      eligible_grants.each do |grant|
        next unless grant.active_now?
        next unless grant.grantee_person_id.present?

        ::BetterTogether::FederatedLinkedSeedPullJob.perform_later(
          platform_connection_id: grant.person_link.platform_connection_id,
          recipient_person_id: grant.grantee_person_id
        )
      end
    end

    private

    def eligible_grants
      ::BetterTogether::PersonAccessGrant.active
                                         .joins(person_link: :platform_connection)
                                         .includes(:grantee_person, person_link: :platform_connection)
                                         .where(
                                           better_together_platform_connections: {
                                             status: ::BetterTogether::PlatformConnection::STATUS_VALUES[:active]
                                           }
                                         )
                                         .select do |grant|
        grant.person_link.platform_connection.linked_content_read_enabled?
      end
    end
  end
end
