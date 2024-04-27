# frozen_string_literal: true

module BetterTogether
  # Tracks a person's platform memberships and their roles
  class PersonPlatformMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Platform'
  end
end
