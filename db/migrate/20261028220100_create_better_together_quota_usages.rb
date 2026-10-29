# frozen_string_literal: true

class CreateBetterTogetherQuotaUsages < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota_usages)

    create_bt_table :quota_usages do |t|
      t.bt_references :quota, null: false, index: { name: 'index_bt_quota_usages_on_quota' }
      t.string :quota_type, null: false
      t.bigint :amount, null: false
      t.string :period_key, null: false
      t.bt_references :subject, polymorphic: true, null: true,
                                index: { name: 'index_bt_quota_usages_on_subject' }
      t.bt_references :actor, polymorphic: true, null: true,
                              index: { name: 'index_bt_quota_usages_on_actor' }
      t.bt_references :owner, polymorphic: true, null: false,
                              index: { name: 'index_bt_quota_usages_on_owner' }
      t.bt_references :platform, null: true
      t.jsonb :context, null: false, default: {}
      t.string :idempotency_key, null: false
      t.string :event, null: false
    end

    add_index :better_together_quota_usages, %i[subject_type subject_id event],
              unique: true, name: 'index_bt_quota_usages_on_subject_and_event'
    add_index :better_together_quota_usages, :idempotency_key,
              unique: true, name: 'index_bt_quota_usages_on_idempotency_key'
    add_index :better_together_quota_usages, :period_key
  end
end
