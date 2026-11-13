# frozen_string_literal: true

module BetterTogether
  module TrustedDomains
    # Gives a person with a verified trusted-domain address membership in the platform's community, and writes
    # the audit entry. Only ever adds the domain's role: an existing active membership is left as it is.
    class Grant
      Result = Struct.new(:status, :membership, :event, keyword_init: true) do
        def granted? = status == :granted
      end

      def self.call(...)
        new(...).call
      end

      # created_account: true when this sign-up created the account (as opposed to adding access to one).
      def initialize(trusted_domain:, person:, via:, created_account: false)
        @trusted_domain = trusted_domain
        @person = person
        @via = via
        @created_account = created_account
      end

      def call
        community = platform.community
        return Result.new(status: :no_community) if community.blank? || @person.blank?

        ActiveRecord::Base.transaction do
          memberships = community.person_community_memberships.where(member: @person)
          next Result.new(status: :already_member, membership: memberships.active.first) if memberships.active.exists?

          Result.new(status: :granted, membership: activate(memberships), event: record_event(community))
        end
      end

      private

      def platform
        @trusted_domain.platform
      end

      # A pending membership (awaiting approval or email confirmation) is upgraded in place, never duplicated.
      def activate(memberships)
        membership = memberships.pending.first || memberships.build
        membership.update!(role: @trusted_domain.role, status: 'active')
        membership
      end

      def record_event(community)
        BetterTogether::TrustedDomainEvent.create!(
          platform:, platform_trusted_domain: @trusted_domain, subject: @person,
          event_type: @created_account ? 'account_created' : 'membership_granted',
          domain: @trusted_domain.domain, role_identifier: @trusted_domain.role.identifier, via: @via,
          details: { community_id: community.id }
        )
      end
    end
  end
end
