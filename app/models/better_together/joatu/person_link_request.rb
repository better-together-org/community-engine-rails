# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request subtype used to propose a person-to-person platform link.
    class PersonLinkRequest < Request
      validates :target_type, inclusion: { in: ['BetterTogether::Person'] }
      validate :target_person_must_exist

      def after_agreement_acceptance!(offer:)
        source_person = offer.target if offer.target.is_a?(::BetterTogether::Person)
        target_person = target
        connection = resolve_platform_connection_for(source_person, target_person)
        validate_link_prerequisites!(source_person, target_person, connection)
        create_person_link!(connection, source_person, target_person)
      end

      private

      def validate_link_prerequisites!(source_person, target_person, connection)
        return if source_person && target_person && connection

        errors.add(:base, 'person link agreements require a source person, target person, and active platform connection')
        raise ActiveRecord::RecordInvalid, self
      end

      def create_person_link!(connection, source_person, target_person)
        person_link = ::BetterTogether::PersonLink.find_or_initialize_by(
          platform_connection: connection,
          source_person:,
          target_person:
        )
        apply_person_link_defaults!(person_link, target_person)
        person_link.save!
      end

      def apply_person_link_defaults!(person_link, target_person)
        person_link.status = :active
        person_link.remote_target_identifier ||= target_person.identifier
        person_link.remote_target_name ||= target_person.name
        person_link.verified_at ||= Time.current
      end

      def target_person_must_exist
        return if target.is_a?(::BetterTogether::Person)

        errors.add(:target, 'must be a person')
      end

      def resolve_platform_connection_for(source_person, target_person)
        return unless source_person && target_person

        source_platform_ids = active_platform_ids_for(source_person)
        target_platform_ids = active_platform_ids_for(target_person)
        return if source_platform_ids.empty? || target_platform_ids.empty?

        ::BetterTogether::PlatformConnection.active.find_by(
          source_platform_id: source_platform_ids,
          target_platform_id: target_platform_ids
        )
      end

      def active_platform_ids_for(person)
        person.person_platform_memberships.active.distinct.pluck(:joinable_id)
      end
    end
  end
end
