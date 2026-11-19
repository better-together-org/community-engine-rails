# frozen_string_literal: true

module BetterTogether
  module Billing
    module Entitlements
      module Handlers
        # A role in the platform or in one of its communities.
        #
        #   { "joinable": "platform", "role": "supporter" }
        #   { "joinable": "community", "community_id": "<uuid>", "role": "member" }
        #
        # * **Only unprivileged roles.** A role is grantable only when every permission it holds is read-only (an allowlist of
        #   actions); any other permission makes it privileged, whatever it is named.
        # * **Only this platform's** platform and communities.
        # * A membership the person already has (invited, added by hand) is **adopted and never taken away**
        #   (`owned: false`). Only a membership this entitlement made is removed when it lapses.
        # * Memberships are made and removed one record at a time, never in bulk, so the usual callbacks run:
        #   the person's permission cache is expired at once. Their "you were added / removed" emails are
        #   suppressed (`suppress_notifications`); a paid role is not news in the way an invitation is.
        class MembershipRole < Base
          READ_ONLY_ACTIONS = %w[read view list show].freeze

          # A role is privileged unless every permission it holds is read-only.
          def self.privileged_role?(role)
            role.resource_permissions.pluck(:action).any? { |action| READ_ONLY_ACTIONS.exclude?(action.to_s.downcase) }
          end

          def self.parameter_errors(parameters, platform:)
            new(parameters, platform:).errors
          end

          def errors
            list = []
            list << :joinable_unknown unless %w[platform community].include?(parameters['joinable'])
            list << :community_unknown if community? && community.nil?
            list << :role_unknown if role.nil?
            list << :role_privileged if role && privileged?(role)
            list
          end

          def kind = 'membership_role'

          def key = "membership_role:#{community? ? "community:#{parameters['community_id']}" : 'platform'}:#{parameters['role']}"

          # Memberships belong to people.
          def applies_to?(beneficiary) = beneficiary.is_a?(BetterTogether::Person) && errors.empty?

          def apply(entitlement)
            person = entitlement.beneficiary
            existing = memberships.find_by(member_id: person.id, joinable_id: joinable.id, role_id: role.id)
            return Applied.new(record: existing, owned: false) if existing

            Applied.new(record: create_membership(entitlement, person), owned: true)
          end

          def release(grant)
            membership = grant.applied
            return unless grant.owned && membership

            membership.suppress_notifications = true
            membership.destroy!
          end

          private

          def community? = parameters['joinable'] == 'community'

          def joinable
            @joinable ||= community? ? community : platform
          end

          def community
            @community ||= BetterTogether::Community.find_by(id: parameters['community_id'], platform_id: platform.id)
          end

          def role
            return @role if defined?(@role)

            @role = BetterTogether::Role.find_by(identifier: parameters['role'], resource_type: joinable_class.name)
          end

          def joinable_class = community? ? BetterTogether::Community : BetterTogether::Platform

          def memberships = community? ? BetterTogether::PersonCommunityMembership : BetterTogether::PersonPlatformMembership

          def privileged?(found) = self.class.privileged_role?(found)

          def create_membership(entitlement, person)
            attributes = { member: person, joinable:, role:, status: 'active' }
            attributes[:platform_id] = entitlement.platform_id if community?
            memberships.new(attributes).tap do |membership|
              membership.suppress_notifications = true
              membership.save!
            end
          end
        end
      end
    end
  end
end
