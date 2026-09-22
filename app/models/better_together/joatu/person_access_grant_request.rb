# frozen_string_literal: true

module BetterTogether
  module Joatu
    # Request subtype used to propose a fail-closed private access grant between linked people.
    class PersonAccessGrantRequest < Request
      validates :target_type, inclusion: { in: ['BetterTogether::Person'] }
      validate :target_person_must_exist

      def after_agreement_acceptance!(offer:)
        grantor_person = offer.target if offer.target.is_a?(::BetterTogether::Person)
        grantee_person = target
        person_link = resolve_or_activate_person_link!(grantor_person, grantee_person)
        create_access_grant!(person_link, grantor_person, grantee_person)
      end

      private

      def create_access_grant!(person_link, grantor_person, grantee_person)
        grant = ::BetterTogether::PersonAccessGrant.find_or_initialize_by(
          person_link:,
          grantor_person:,
          grantee_person:
        )
        apply_grant_defaults!(grant, grantee_person)
        grant.save!
      end

      def apply_grant_defaults!(grant, grantee_person)
        grant.status = :active
        grant.remote_grantee_identifier ||= grantee_person.identifier
        grant.remote_grantee_name ||= grantee_person.name
        grant.accepted_at ||= Time.current
        grant.allow_profile_read = true if grant.new_record?
      end

      def target_person_must_exist
        return if target.is_a?(::BetterTogether::Person)

        errors.add(:target, 'must be a person')
      end

      def resolve_or_activate_person_link!(grantor_person, grantee_person)
        connection = find_link_connection(grantor_person, grantee_person)
        validate_link_connection!(grantor_person, grantee_person, connection)
        activate_person_link!(connection, grantor_person, grantee_person)
      end

      def find_link_connection(grantor_person, grantee_person)
        request = ::BetterTogether::Joatu::PersonLinkRequest.new(target: grantee_person)
        request.send(:resolve_platform_connection_for, grantor_person, grantee_person)
      end

      def validate_link_connection!(grantor_person, grantee_person, connection)
        return if grantor_person && grantee_person && connection

        errors.add(:base, 'person access grants require an active person link or resolvable platform connection')
        raise ActiveRecord::RecordInvalid, self
      end

      def activate_person_link!(connection, grantor_person, grantee_person)
        link = ::BetterTogether::PersonLink.find_or_initialize_by(
          platform_connection: connection,
          source_person: grantor_person,
          target_person: grantee_person
        )
        link.status = :active
        link.remote_target_identifier ||= grantee_person.identifier
        link.remote_target_name ||= grantee_person.name
        link.verified_at ||= Time.current
        link.save!
        link
      end
    end
  end
end
