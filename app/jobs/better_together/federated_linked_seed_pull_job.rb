# frozen_string_literal: true

module BetterTogether
  # Pulls recipient-scoped private linked seeds for one PersonAccessGrant and
  # caches them locally. Persists the remote cursor after each pull so
  # subsequent runs resume from the correct page, not page 1.
  class FederatedLinkedSeedPullJob < ApplicationJob # rubocop:disable Metrics/MethodLength
    DISPATCH_LOCK_NAMESPACE = 'bt:federation:linked_seed_dispatch'

    queue_as :platform_sync

    def perform(platform_connection_id:, recipient_person_id:, sync_cursor: nil, person_access_grant_id: nil, dispatch_lock_token: nil)
      connection = ::BetterTogether::PlatformConnection.find(platform_connection_id)
      recipient_person = ::BetterTogether::Person.find(recipient_person_id)
      return unless eligible_grant_exists?(connection:, recipient_person:)

      process_pull(
        connection:,
        recipient_person:,
        sync_cursor:,
        person_access_grant_id:
      )
    ensure
      release_dispatch_lock_if_owner(person_access_grant_id:, dispatch_lock_token:)
    end

    private

    RELEASE_LOCK_SCRIPT = <<~LUA
      if redis.call("get", KEYS[1]) == ARGV[1] then
        return redis.call("del", KEYS[1])
      else
        return 0
      end
    LUA
    private_constant :RELEASE_LOCK_SCRIPT

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

    def process_pull(connection:, recipient_person:, sync_cursor:, person_access_grant_id:)
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

    def release_dispatch_lock_if_owner(person_access_grant_id:, dispatch_lock_token:)
      return if person_access_grant_id.blank? || dispatch_lock_token.blank?

      Sidekiq.redis do |redis|
        redis.call(
          'EVAL',
          RELEASE_LOCK_SCRIPT,
          1,
          dispatch_lock_key(person_access_grant_id),
          dispatch_lock_token
        )
      end
    end

    def dispatch_lock_key(person_access_grant_id)
      "#{DISPATCH_LOCK_NAMESPACE}/#{person_access_grant_id}"
    end
  end
end
