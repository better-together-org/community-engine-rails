# frozen_string_literal: true

# Phase 1 of platform tenancy: accounts belong to one platform.
# - backfills users.platform_id with the host platform (all existing accounts belong to the host;
#   other platform rows are external ones for OAuth providers and federation)
# - replaces the global unique email index with a unique (platform_id, lower(email)) index
# - makes platform_id NOT NULL with a foreign key
class ScopeUserEmailToPlatform < ActiveRecord::Migration[7.1]
  USERS = :better_together_users
  OLD_INDEX = 'index_better_together_users_on_email'
  NEW_INDEX = 'index_bt_users_on_platform_and_lower_email'

  def up
    return unless table_exists?(USERS) && column_exists?(USERS, :platform_id)

    backfill_from_host_platform
    add_scoped_email_index
    remove_index USERS, name: OLD_INDEX if index_name_exists?(USERS, OLD_INDEX)
    enforce_not_null_and_foreign_key
  end

  def down
    return unless table_exists?(USERS)

    remove_index USERS, name: NEW_INDEX if index_name_exists?(USERS, NEW_INDEX)
    add_index USERS, :email, unique: true, name: OLD_INDEX unless index_name_exists?(USERS, OLD_INDEX)
    change_column_null USERS, :platform_id, true
  end

  private

  def backfill_from_host_platform
    host_id = select_value('SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1')
    return unless host_id

    execute <<~SQL.squish
      UPDATE #{USERS}
      SET platform_id = #{quote(host_id)}
      WHERE platform_id IS NULL
    SQL
  end

  def add_scoped_email_index
    return if index_name_exists?(USERS, NEW_INDEX)

    add_index USERS, 'platform_id, lower(email)', unique: true, name: NEW_INDEX
  end

  # Fails closed: if any user still has no platform, leave the column nullable and say so loudly.
  def enforce_not_null_and_foreign_key
    remaining = select_value("SELECT COUNT(*) FROM #{USERS} WHERE platform_id IS NULL").to_i
    if remaining.positive?
      raise "#{remaining} users have no platform_id and no host platform exists to assign; resolve before migrating"
    end

    change_column_null USERS, :platform_id, false
    return if foreign_key_exists?(USERS, :better_together_platforms, column: :platform_id)

    add_foreign_key USERS, :better_together_platforms, column: :platform_id
  end
end
