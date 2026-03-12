# frozen_string_literal: true

module BetterTogether
  class FederatedLinkedSeedPullJob < ApplicationJob
    queue_as :platform_sync

    def perform(platform_connection_id:, recipient_person_id:, sync_cursor: nil)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      recipient_person = ::BetterTogether::Person.find(recipient_person_id)
      return unless eligible_grant_exists?(connection:, recipient_person:)

      pull_result = ::BetterTogether::FederatedLinkedSeedPullService.call(
        connection:,
        recipient_identifier: recipient_person.identifier,
        cursor: sync_cursor
      )

      ::BetterTogether::Seeds::LinkedSeedIngestService.call(
        connection:,
        recipient_person:,
        seeds: pull_result.seeds
      )
    end

    private

    def eligible_grant_exists?(connection:, recipient_person:)
      ::BetterTogether::PersonAccessGrant.current_active
                                         .for_connection(connection)
                                         .for_recipient(recipient_person)
                                         .exists?
    end
  end
end
