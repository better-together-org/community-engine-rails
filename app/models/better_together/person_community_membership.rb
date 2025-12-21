# frozen_string_literal: true

module BetterTogether
  # Used to represent a person's connection to a community with a specific role
  class PersonCommunityMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Community'

    after_create_commit :notify_member_of_creation

    private

    def notify_member_of_creation
      return unless member

      BetterTogether::MembershipCreatedNotifier.with(membership: self, record: self).deliver_later(member)
    end
  end
end
