# frozen_string_literal: true

# Phase 8 — Communities are per-platform. Add platform_id FK.
class AddPlatformIdToCommunities < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_communities, :platform_id)

    add_reference :better_together_communities, :platform,
                  type: :uuid, null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
