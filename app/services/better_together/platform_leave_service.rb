# frozen_string_literal: true

module BetterTogether
  # A member leaves the platform their account belongs to (P1-5). Removes the person's
  # platform memberships there; the last steward cannot leave.
  class PlatformLeaveService
    class LastStewardError < StandardError; end

    def self.call(**) = new(**).call

    def initialize(person:, platform:)
      @person = person
      @platform = platform
    end

    def call
      memberships = PersonPlatformMembership.where(member: @person, joinable: @platform)
      raise LastStewardError, 'last steward cannot leave' if last_steward?(memberships)

      memberships.destroy_all.size
    end

    private

    def last_steward?(memberships)
      return false unless memberships.joins(:role).exists?(better_together_roles: { identifier: 'platform_steward' })

      steward_count = PersonPlatformMembership.joins(:role)
                                              .where(joinable: @platform, status: 'active',
                                                     better_together_roles: { identifier: 'platform_steward' })
                                              .distinct.count(:member_id)
      steward_count <= 1
    end
  end
end
