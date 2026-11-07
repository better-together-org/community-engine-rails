# frozen_string_literal: true

class CreateBetterTogetherQuotaReservations < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota_reservations)

    create_bt_table :quota_reservations do |t|
      # target_table pinned to the singular table - see the identical comment in
      # 20261028220100_create_better_together_quota_usages.rb for why.
      t.bt_references :quota, target_table: :better_together_quota, null: false,
                              index: { name: 'index_bt_quota_reservations_on_quota' }
      t.string :quota_type, null: false
      t.bigint :amount, null: false
      t.string :period_key, null: false
      t.bt_references :subject, polymorphic: true, null: true,
                                index: { name: 'index_bt_quota_reservations_on_subject' }
      t.bt_references :actor, polymorphic: true, null: true,
                              index: { name: 'index_bt_quota_reservations_on_actor' }
      t.bt_references :owner, polymorphic: true, null: false,
                              index: { name: 'index_bt_quota_reservations_on_owner' }
      t.string :status, null: false, default: 'held'
      t.datetime :expires_at, null: false
      t.datetime :settled_at
      t.datetime :released_at
      t.string :idempotency_key, null: false
      t.jsonb :context, null: false, default: {}
    end

    add_index :better_together_quota_reservations, :idempotency_key,
              unique: true, name: 'index_bt_quota_reservations_on_idempotency_key'
    add_index :better_together_quota_reservations, %i[status expires_at],
              name: 'index_bt_quota_reservations_on_status_and_expiry'
  end
end
