# frozen_string_literal: true

# Phase 7 — People are per-platform. Every person record belongs to exactly one platform.
class AddPlatformIdToPeople < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_people, :platform_id)

    add_reference :better_together_people, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
