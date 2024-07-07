# frozen_string_literal: true

# Creates community memberships table
class CreateBetterTogetherPersonCommunityMemberships < ActiveRecord::Migration[7.0]
  def change
    create_bt_membership_table :person_community_memberships,
                               member_type: 'person',
                               joinable_type: 'community'
  end
end
