# frozen_string_literal: true

# A time-limited, audited grant letting one person read one private record. Nothing consumes it yet.
class CreateBetterTogetherBreakGlassGrants < ActiveRecord::Migration[8.1]
  def up
    return if table_exists?(:better_together_break_glass_grants)

    create_bt_table :break_glass_grants do |t|
      t.string :status, null: false, default: 'requested'
      t.text :reason, null: false
      t.string :reason_code
      t.boolean :emergency, null: false, default: false
      t.datetime :available_at, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.bt_references :subject, polymorphic: true, null: false, index: { name: 'index_break_glass_grants_on_subject' }
      t.bt_references :grantee, null: false, target_table: :better_together_people
      t.bt_references :requested_by, null: false, target_table: :better_together_people
      t.bt_references :approved_by, null: true, target_table: :better_together_people
      t.bt_references :platform, null: false, index: { name: 'index_better_together_break_glass_grants_on_platform_id' }
    end

    add_index :better_together_break_glass_grants, %i[grantee_id subject_type subject_id],
              name: 'index_break_glass_grants_on_grantee_and_subject'
  end

  def down
    drop_table :better_together_break_glass_grants if table_exists?(:better_together_break_glass_grants)
  end
end
