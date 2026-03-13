# frozen_string_literal: true

module BetterTogether
  module Seeds
    # Caches recipient-scoped private seed payloads behind an active person access grant.
    class PersonLinkedSeedCacheService
      Result = Struct.new(:linked_seed, :created, keyword_init: true)

      # Holds seed-specific attributes separately from grant/person context.
      SeedAttributes = Struct.new(
        :identifier, :seed_type, :payload,
        :source_record_type, :source_record_id, :version,
        :source_updated_at, :metadata,
        keyword_init: true
      ) do
        def self.from_hash(hash)
          new(**hash.slice(*members.map(&:to_s).map(&:to_sym)))
        end
      end

      def self.call(person_access_grant:, recipient_person:, source_platform:, seed_attributes:)
        new(
          person_access_grant:,
          recipient_person:,
          source_platform:,
          seed_attributes: seed_attributes.is_a?(SeedAttributes) ? seed_attributes : SeedAttributes.from_hash(seed_attributes)
        ).call
      end

      def initialize(person_access_grant:, recipient_person:, source_platform:, seed_attributes:)
        @person_access_grant = person_access_grant
        @recipient_person = recipient_person
        @source_platform = source_platform
        @seed_attributes = seed_attributes
      end

      def call
        raise ActiveRecord::RecordInvalid, person_access_grant unless person_access_grant.active_now?
        raise ArgumentError, 'recipient must match grant grantee' unless person_access_grant.grantee_person_id == recipient_person.id

        linked_seed, created = upsert_linked_seed
        Result.new(linked_seed:, created:)
      end

      private

      attr_reader :person_access_grant, :recipient_person, :source_platform, :seed_attributes

      def upsert_linked_seed
        record = ::BetterTogether::PersonLinkedSeed.find_or_initialize_by(
          person_access_grant:,
          identifier: seed_attributes.identifier
        )
        created = record.new_record?
        record.assign_attributes(linked_seed_attributes)
        record.save!
        [record, created]
      end

      def linked_seed_attributes
        seed_identity_attributes.merge(seed_content_attributes).merge(seed_sync_attributes)
      end

      def seed_identity_attributes
        {
          recipient_person:,
          source_platform:,
          seed_type: seed_attributes.seed_type
        }
      end

      def seed_content_attributes
        {
          payload: normalize_payload(seed_attributes.payload),
          source_record_type: seed_attributes.source_record_type,
          source_record_id: seed_attributes.source_record_id.to_s,
          version: seed_attributes.version
        }
      end

      def seed_sync_attributes
        {
          source_updated_at: seed_attributes.source_updated_at,
          last_synced_at: Time.current,
          metadata: seed_attributes.metadata || {}
        }
      end

      def normalize_payload(value)
        value.is_a?(String) ? value : JSON.generate(value)
      end
    end
  end
end
