# frozen_string_literal: true

# Add status enum column to person membership tables
class AddStatusToPersonMemberships < ActiveRecord::Migration[7.2]
  def up
    add_membership_status(:better_together_person_platform_memberships)
    add_membership_status(:better_together_person_community_memberships)
  end

  def down
    remove_membership_status(:better_together_person_platform_memberships)
    remove_membership_status(:better_together_person_community_memberships)
  end

  private

  def add_membership_status(table_name)
    add_column(table_name, :status, :string) unless column_exists?(table_name, :status)

    execute <<~SQL.squish
      UPDATE #{table_name}
      SET status = 'active'
      WHERE status IS NULL
    SQL

    change_column_default table_name, :status, from: nil, to: 'pending'
    change_column_null table_name, :status, false, 'active'
    add_index(table_name, :status) unless index_exists?(table_name, :status)
  end

  def remove_membership_status(table_name)
    remove_index(table_name, :status) if index_exists?(table_name, :status)
    remove_column(table_name, :status) if column_exists?(table_name, :status)
  end
end
