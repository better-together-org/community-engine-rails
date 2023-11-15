module BetterTogether
  class PersonCommunityMembership < ApplicationRecord
    belongs_to  :community
    belongs_to  :member,
                class_name: '::BetterTogether::Person'
    belongs_to  :role

    validates :role, uniqueness: {
      scope: %i[community_id member_id]
    }
  end
end
