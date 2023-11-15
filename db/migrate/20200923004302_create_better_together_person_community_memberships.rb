class CreateBetterTogetherPersonCommunityMemberships < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :person_community_memberships do |t|
      # Reference to the better_together_people table for the member
      t.bt_references :member, null: false, index: { name: 'person_community_membership_by_member' }, target_table: :better_together_people

      # Reference to the better_together_communities table for the community
      t.bt_references :community, null: false, index: { name: 'person_community_membership_by_community' }, target_table: :better_together_communities

      # Reference to the better_together_roles table for the role
      t.bt_references :role, null: false, index: { name: 'person_community_membership_by_role' }, target_table: :better_together_roles

      # Unique composite index
      t.index %i[community_id member_id role_id], unique: true, name: 'unique_person_community_membership_member_role'

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
