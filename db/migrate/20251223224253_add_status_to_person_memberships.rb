# frozen_string_literal: true

# Add status enum column to person membership tables
class AddStatusToPersonMemberships < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_person_platform_memberships, :status, :string, default: 'pending', null: false
    add_column :better_together_person_community_memberships, :status, :string, default: 'pending', null: false

    add_index :better_together_person_platform_memberships, :status
    add_index :better_together_person_community_memberships, :status
  end
end
