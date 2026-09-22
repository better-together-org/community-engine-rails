# frozen_string_literal: true

# Phase 9 — Critical isolation: Conversations, Messages, Activities, Reports, PersonBlocks, Invitations, Authorships
class AddPlatformIdToCriticalIsolationTables < ActiveRecord::Migration[7.2]
  def change
    %w[
      better_together_conversations
      better_together_messages
      better_together_activities
      better_together_reports
      better_together_person_blocks
      better_together_invitations
      better_together_authorships
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
