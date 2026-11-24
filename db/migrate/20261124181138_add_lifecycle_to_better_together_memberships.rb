# frozen_string_literal: true

# Gives platform and community memberships a lifecycle: when it starts and ends, why it ended, and where it
# came from, plus an append-only event table so history survives a role change, an end or a delete.
#
#   - starts_at / ends_at: optional bounds. A membership counts as active only inside them.
#   - ended_reason: free text for an ended or suspended row.
#   - source: how the row came to be (direct, registration, invitation, request, trusted_domain, entitlement, backfill).
#   - The unique key (joinable, member, role) now ignores ended rows, so a person can be given a role again
#     after it ended and the ended row stays as history.
#   - Existing active rows get starts_at = created_at.
class AddLifecycleToBetterTogetherMemberships < ActiveRecord::Migration[7.2]
  TABLES = {
    better_together_person_platform_memberships: 'unique_person_platform_membership_member_role',
    better_together_person_community_memberships: 'unique_person_community_membership_member_role'
  }.freeze

  def up
    TABLES.each do |table, unique_name|
      add_lifecycle_columns(table)
      ends_at_index = "index_#{table}_on_ends_at"
      add_index table, :ends_at, name: ends_at_index unless index_name_exists?(table, ends_at_index)
      replace_unique_index(table, unique_name)
      execute "UPDATE #{table} SET starts_at = created_at WHERE status = 'active' AND starts_at IS NULL"
    end

    create_membership_events
  end

  def down
    drop_table :better_together_membership_events if table_exists?(:better_together_membership_events)

    TABLES.each do |table, unique_name|
      # Ended rows would break the full unique key, so they go before it is restored.
      execute "DELETE FROM #{table} WHERE status = 'ended'"
      remove_index table, name: unique_name if index_name_exists?(table, unique_name)
      add_index table, %i[joinable_id member_id role_id], unique: true, name: unique_name
      remove_index table, name: "index_#{table}_on_ends_at" if index_name_exists?(table, "index_#{table}_on_ends_at")
      %i[source ended_reason ends_at starts_at].each do |column|
        remove_column table, column if column_exists?(table, column)
      end
    end
  end

  private

  def add_lifecycle_columns(table)
    add_column table, :starts_at, :datetime unless column_exists?(table, :starts_at)
    add_column table, :ends_at, :datetime unless column_exists?(table, :ends_at)
    add_column table, :ended_reason, :string unless column_exists?(table, :ended_reason)
    add_column table, :source, :string, default: 'direct', null: false unless column_exists?(table, :source)
  end

  def replace_unique_index(table, unique_name)
    remove_index table, name: unique_name if index_name_exists?(table, unique_name)
    add_index table, %i[joinable_id member_id role_id], unique: true, where: "status <> 'ended'", name: unique_name
  end

  def create_membership_events
    return if table_exists?(:better_together_membership_events)

    create_bt_table :membership_events do |t|
      t.string :membership_type, null: false
      t.uuid :membership_id, null: false
      t.string :joinable_type, null: false
      t.uuid :joinable_id, null: false
      t.bt_references :member, target_table: :better_together_people, null: false,
                               index: { name: 'index_bt_membership_events_on_member' }
      t.bt_references :actor, target_table: :better_together_people, null: true,
                              index: { name: 'index_bt_membership_events_on_actor' }
      t.bt_references :platform, null: true, index: { name: 'index_bt_membership_events_on_platform' }
      t.string :event_type, null: false
      t.string :from_status
      t.string :to_status
      t.uuid :from_role_id
      t.uuid :to_role_id
      t.string :reason
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_membership_events, %i[membership_type membership_id created_at],
              name: 'index_bt_membership_events_on_membership'
    add_index :better_together_membership_events, %i[joinable_type joinable_id created_at],
              name: 'index_bt_membership_events_on_joinable'
  end
end
