# frozen_string_literal: true

# Phase 7 — Identifications link platform-scoped users to platform-scoped people;
# denormalize platform_id for efficient scoped queries.
class AddPlatformIdToIdentifications < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_identifications, :platform_id)

    add_reference :better_together_identifications, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
