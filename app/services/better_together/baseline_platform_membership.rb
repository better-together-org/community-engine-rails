# frozen_string_literal: true

module BetterTogether
  # Every account holds the platform_member role on the platform it belongs to. This is the baseline
  # membership: free, read access, never billed. Elevated and paid roles are separate rows that stack on it.
  #
  # Idempotent and never downgrades: an existing membership (any status) is returned as it is, so an
  # invitation that already made it active is not set back to pending. Status is the caller's choice;
  # sign-up passes 'pending' until the email is confirmed, and confirmation activates it.
  class BaselinePlatformMembership
    IDENTIFIER = 'platform_member'

    def self.call(...)
      new(...).call
    end

    def initialize(person:, platform:, status: 'active')
      @person = person
      @platform = platform
      @status = status
    end

    # The membership, or nil when there is nothing to do (no person, remote platform, no role).
    def call
      return if @person.blank? || @platform.blank? || @platform.remote?

      role = Role.find_default(IDENTIFIER, platform: @platform)
      return if role.blank?

      @platform.person_platform_memberships.find_or_create_by!(member: @person, role:) do |membership|
        membership.status = @status
        # Everyone gets this row, so it is not an event worth a notification.
        membership.suppress_notifications = true
      end
    end
  end
end
