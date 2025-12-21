# frozen_string_literal: true

module BetterTogether
  # Tracks a person's platform memberships and their roles
  class PersonPlatformMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Platform'

    after_create_commit :notify_member_of_creation

    private

    def notify_member_of_creation
      return unless member

      BetterTogether::MembershipCreatedNotifier.with(membership: self, record: self).deliver_later(member)
    end
  end
end
