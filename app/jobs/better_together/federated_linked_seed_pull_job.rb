# frozen_string_literal: true

module BetterTogether
  # Pulls recipient-scoped private linked seeds for one PersonAccessGrant and
  # caches them locally. Persists the remote cursor after each pull so
  # subsequent runs resume from the correct page, not page 1.
  class FederatedLinkedSeedPullJob < ApplicationJob # rubocop:disable Metrics/MethodLength
    queue_as :platform_sync

    def perform(platform_connection_id:, recipient_person_id:, sync_cursor: nil, person_access_grant_id: nil)
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

      persist_cursor(person_access_grant_id:, next_cursor: pull_result.next_cursor)
    end

    private

    def eligible_grant_exists?(connection:, recipient_person:)
      ::BetterTogether::PersonAccessGrant.current_active
                                         .for_connection(connection)
                                         .for_recipient(recipient_person)
                                         .exists?
    end

    def persist_cursor(person_access_grant_id:, next_cursor:)
      return if person_access_grant_id.blank?

      grant = ::BetterTogether::PersonAccessGrant.current_active.find_by(id: person_access_grant_id)
      grant&.update_columns(sync_cursor: next_cursor.presence)
    end
  end
end
