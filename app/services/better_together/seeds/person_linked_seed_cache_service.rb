# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Caches recipient-scoped private seed payloads behind an active person access grant.
    class PersonLinkedSeedCacheService
      Result = Struct.new(:linked_seed, :created, keyword_init: true)

      def self.call(...)
        new(...).call
      end

      def initialize(person_access_grant:, recipient_person:, source_platform:, identifier:, seed_type:, payload:,
                     source_record_type:, source_record_id:, version:, source_updated_at: nil, metadata: {})
        @person_access_grant = person_access_grant
        @recipient_person = recipient_person
        @source_platform = source_platform
        @identifier = identifier
        @seed_type = seed_type
        @payload = payload
        @source_record_type = source_record_type
        @source_record_id = source_record_id
        @version = version
        @source_updated_at = source_updated_at
        @metadata = metadata
      end

      def call
        raise ActiveRecord::RecordInvalid, person_access_grant unless person_access_grant.active_now?
        raise ArgumentError, 'recipient must match grant grantee' unless person_access_grant.grantee_person_id == recipient_person.id

        linked_seed = ::BetterTogether::PersonLinkedSeed.find_or_initialize_by(
          person_access_grant:,
          identifier:
        )

        created = linked_seed.new_record?
        linked_seed.assign_attributes(
          recipient_person:,
          source_platform:,
          seed_type:,
          payload: normalize_payload(payload),
          source_record_type:,
          source_record_id: source_record_id.to_s,
          version:,
          source_updated_at:,
          last_synced_at: Time.current,
          metadata:
        )
        linked_seed.save!

        Result.new(linked_seed:, created:)
      end

      private

      attr_reader :person_access_grant, :recipient_person, :source_platform, :identifier, :seed_type, :payload,
                  :source_record_type, :source_record_id, :version, :source_updated_at, :metadata

      def normalize_payload(value)
        value.is_a?(String) ? value : JSON.generate(value)
      end
    end
  end
end
