# frozen_string_literal: true

# Append-only audit trail for break-glass grants: request, revoke and every read made under a grant.
class CreateBetterTogetherBreakGlassEvents < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:better_together_break_glass_events)

    create_bt_table :break_glass_events do |t|
      t.string :event_type, null: false
      t.jsonb :detail, null: false, default: {}
      t.bt_references :break_glass_grant, null: false, index: { name: 'index_break_glass_events_on_grant' }
      t.bt_references :actor, null: true, target_table: :better_together_people
      t.bt_references :platform, null: false, index: { name: 'index_better_together_break_glass_events_on_platform_id' }
    end
  end

  def down
    drop_table :better_together_break_glass_events if table_exists?(:better_together_break_glass_events)
  end
end
