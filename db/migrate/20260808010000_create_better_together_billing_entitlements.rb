# frozen_string_literal: true

class CreateBetterTogetherBillingEntitlements < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_entitlements)

    create_bt_table :billing_entitlements do |t|
      t.references :holder,
                   type: :uuid,
                   polymorphic: true,
                   null: false
      t.references :source,
                   type: :uuid,
                   polymorphic: true,
                   null: true
      t.references :billing_plan,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_billing_plans }
      t.references :granted_by,
                   type: :uuid,
                   polymorphic: true,
                   null: true
      t.string :entitlement_key, null: false
      t.string :status, null: false, default: 'active'
      t.datetime :granted_at, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_entitlements,
              %i[holder_type holder_id entitlement_key status],
              name: 'idx_bt_billing_entitlements_holder_key_status'
    add_index :better_together_billing_entitlements,
              %i[holder_type holder_id entitlement_key source_type source_id],
              unique: true, name: 'idx_bt_billing_entitlements_holder_key_source_uniq'
  end
end
