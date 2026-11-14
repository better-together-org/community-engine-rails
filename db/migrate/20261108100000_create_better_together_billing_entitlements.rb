# frozen_string_literal: true

# What being subscribed (or having bought a one-time plan) gives a person or community. Final state; guarded so
# a re-run, or an interrupted earlier run, is a no-op for what exists.
#
# * plan_grants: what a plan includes. `kind` is one of an allow-list (a role in a platform or community, access
#   to a gated feature, a quota allowance); `parameters` says which, validated per kind.
# * entitlements: one per source (a Pay subscription, or a paid one-time order) and what it is for. Its status
#   follows the source: active, grace (past due, everything still works), lapsed, revoked (refunded), ended.
# * entitlement_grants: what was ACTUALLY applied for an entitlement, with `owned` saying whether it made the
#   thing (a membership, a feature grant) or only found it already there. Only what an entitlement owns is ever
#   taken away. `grant_key` names the grant, unique per entitlement, so applying twice is harmless, and the
#   kind and parameters are copied so editing a plan never loses track of what was applied.
#
# platform_id is NOT NULL and the links to the plan, the Pay subscription, the order and the entitlement are
# COMPOSITE foreign keys with the platform, so a row can never point at another platform's.
class CreateBetterTogetherBillingEntitlements < ActiveRecord::Migration[7.2]
  def up
    create_plan_grants
    create_entitlements
    create_entitlement_grants
  end

  def down
    %i[billing_entitlement_grants billing_entitlements billing_plan_grants].each do |name|
      table = :"better_together_#{name}"
      drop_table table, force: :cascade if table_exists?(table)
    end
  end

  private

  def create_plan_grants
    return if table_exists?(:better_together_billing_plan_grants)

    create_bt_table :billing_plan_grants do |t|
      t.uuid :platform_id, null: false
      t.uuid :plan_id, null: false
      t.string :kind, null: false
      t.jsonb :parameters, null: false, default: {}
      t.integer :position, null: false, default: 0
    end
    table = :better_together_billing_plan_grants
    add_index table, :platform_id, name: 'idx_bt_billing_plan_grants_platform'
    add_index table, %i[plan_id position], name: 'idx_bt_billing_plan_grants_plan'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_plan_grants_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_plans, column: %i[plan_id platform_id], primary_key: %i[id platform_id],
                                                           name: 'fk_bt_billing_plan_grants_plan_platform'
  end

  def create_entitlements
    return if table_exists?(:better_together_billing_entitlements)

    create_bt_table :billing_entitlements do |t|
      t.uuid :platform_id, null: false
      t.uuid :plan_id, null: false
      t.string :beneficiary_type, null: false
      t.uuid :beneficiary_id, null: false
      t.uuid :pay_subscription_id
      t.uuid :order_id
      t.string :status, null: false, default: 'active'
      t.datetime :starts_at, null: false
      t.datetime :ends_at
      t.datetime :grace_ends_at
    end
    add_entitlement_indexes
  end

  def add_entitlement_indexes
    table = :better_together_billing_entitlements
    add_index table, :platform_id, name: 'idx_bt_billing_entitlements_platform'
    add_index table, :plan_id, name: 'idx_bt_billing_entitlements_plan'
    add_index table, %i[beneficiary_type beneficiary_id], name: 'idx_bt_billing_entitlements_beneficiary'
    add_index table, :pay_subscription_id, unique: true, where: 'pay_subscription_id IS NOT NULL',
                                           name: 'idx_bt_billing_entitlements_subscription'
    add_index table, :order_id, unique: true, where: 'order_id IS NOT NULL', name: 'idx_bt_billing_entitlements_order'
    add_index table, %i[platform_id beneficiary_type beneficiary_id plan_id], unique: true, where: "status IN ('active', 'grace')",
                                                                              name: 'idx_bt_billing_entitlements_one_live'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_entitlements_id_platform'
    add_entitlement_keys(table)
  end

  def add_entitlement_keys(table)
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_plans, column: %i[plan_id platform_id], primary_key: %i[id platform_id],
                                                           name: 'fk_bt_billing_entitlements_plan_platform'
    add_foreign_key table, :pay_subscriptions, column: %i[pay_subscription_id platform_id], primary_key: %i[id platform_id],
                                               name: 'fk_bt_billing_entitlements_subscription_platform'
    add_foreign_key table, :better_together_billing_orders, column: %i[order_id platform_id], primary_key: %i[id platform_id],
                                                            name: 'fk_bt_billing_entitlements_order_platform'
    add_check_constraint table, '(pay_subscription_id IS NOT NULL) <> (order_id IS NOT NULL)', name: 'chk_bt_billing_entitlements_one_source'
  end

  def create_entitlement_grants
    return if table_exists?(:better_together_billing_entitlement_grants)

    create_bt_table :billing_entitlement_grants do |t|
      t.uuid :platform_id, null: false
      t.uuid :entitlement_id, null: false
      t.string :grant_key, null: false
      t.string :kind, null: false
      t.jsonb :parameters, null: false, default: {}
      t.string :applied_type
      t.uuid :applied_id
      t.boolean :owned, null: false, default: false
      t.string :quota_type
      t.bigint :amount, null: false, default: 0
      t.string :status, null: false, default: 'applied'
      t.datetime :released_at
    end
    table = :better_together_billing_entitlement_grants
    add_index table, :platform_id, name: 'idx_bt_billing_ent_grants_platform'
    add_index table, %i[entitlement_id grant_key], unique: true, name: 'idx_bt_billing_ent_grants_key'
    add_index table, %i[applied_type applied_id], name: 'idx_bt_billing_ent_grants_applied'
    add_index table, %i[quota_type status], where: "kind = 'quota_allowance'", name: 'idx_bt_billing_ent_grants_quota'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_entitlements, column: %i[entitlement_id platform_id], primary_key: %i[id platform_id],
                                                                  name: 'fk_bt_billing_ent_grants_entitlement_platform'
    add_check_constraint table, 'amount >= 0', name: 'chk_bt_billing_ent_grants_amount'
  end
end
