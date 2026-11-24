# frozen_string_literal: true

module BetterTogether
  module TrustedDomains
    # Gives a person with a verified trusted-domain address membership in the platform's community, and writes
    # the audit entry. Only ever adds the domain's role: an existing active membership is left as it is.
    class Grant
      # Grants one domain may make per hour; beyond it the person stays pending for steward review.
      HOURLY_LIMIT = ENV.fetch('TRUSTED_DOMAIN_GRANTS_PER_HOUR', 30).to_i

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

        return limited_result if rate_limited?

        result = ActiveRecord::Base.transaction { grant(community) }
        NotifyStewards.call(event: result.event) if result.granted?
        result
      end

      private

      def grant(community)
        memberships = community.person_community_memberships.where(member: @person)
        return Result.new(status: :already_member, membership: memberships.active.first) if memberships.active.exists?

        Result.new(status: :granted, membership: activate(memberships), event: record_event(community))
      end

      def rate_limited?
        BetterTogether::TrustedDomainEvent.account_grants.where(platform_trusted_domain: @trusted_domain)
                                          .where(created_at: 1.hour.ago..).count >= HOURLY_LIMIT
      end

      # Logs and notifies once per hour per domain, so a flood does not become a notification flood.
      def limited_result
        recent = BetterTogether::TrustedDomainEvent.where(platform_trusted_domain: @trusted_domain,
                                                          event_type: 'grant_rate_limited')
                                                   .exists?(['created_at > ?', 1.hour.ago])
        return Result.new(status: :rate_limited) if recent

        event = BetterTogether::TrustedDomainEvent.create!(
          platform:, platform_trusted_domain: @trusted_domain, subject: @person, event_type: 'grant_rate_limited',
          domain: @trusted_domain.domain, role_identifier: @trusted_domain.role.identifier, via: @via
        )
        NotifyStewards.call(event:)
        Result.new(status: :rate_limited, event:)
      end

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
