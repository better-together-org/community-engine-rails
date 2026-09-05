# frozen_string_literal: true

# Phase 2 — Message isolation (inherited from conversation).
# Nullable; backfill copies platform_id from the parent conversation.
class AddPlatformIdToMessages < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_messages, :platform_id)

    add_reference :better_together_messages, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
