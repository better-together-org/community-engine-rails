# frozen_string_literal: true

# Phase 7 — Users are per-platform auth records.
class AddPlatformIdToUsers < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_users, :platform_id)

    add_reference :better_together_users, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
