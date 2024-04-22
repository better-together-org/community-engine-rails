module BetterTogether
  class PersonPlatformMembership < ApplicationRecord
    include Membership

    membership member_class: 'BetterTogether::Person',
               joinable_class: 'BetterTogether::Platform'
  end
end
