# frozen_string_literal: true

# A product can include grants and give an entitlement, as a plan does. A grant belongs to a plan or a product (exactly
# one); an entitlement is for a plan or a product (exactly one) and records how many were bought, so three top-ups give
# three times the allowance. An order may now give several entitlements (one per plan or product on it), so the one per
# order rule becomes one per order and item. Guarded so a re-run is a no-op.
class LetProductsGiveGrantsAndEntitlements < ActiveRecord::Migration[7.2]
  GRANTS = :better_together_billing_plan_grants
  ENTITLEMENTS = :better_together_billing_entitlements

  def up
    change_grants
    change_entitlements
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def change_grants
    unless column_exists?(GRANTS, :product_id)
      add_reference GRANTS, :product, type: :uuid, index: { name: 'idx_bt_billing_plan_grants_product' },
                                      foreign_key: { to_table: :better_together_billing_products }
    end
    change_column_null GRANTS, :plan_id, true
    return if check_constraint_exists?(GRANTS, name: 'chk_bt_billing_plan_grants_one_owner')

    add_check_constraint GRANTS, '(plan_id IS NULL) <> (product_id IS NULL)', name: 'chk_bt_billing_plan_grants_one_owner'
  end

  def change_entitlements
    unless column_exists?(ENTITLEMENTS, :product_id)
      add_reference ENTITLEMENTS, :product, type: :uuid, index: { name: 'idx_bt_billing_entitlements_product' },
                                            foreign_key: { to_table: :better_together_billing_products }
    end
    add_column ENTITLEMENTS, :quantity, :integer, null: false, default: 1 unless column_exists?(ENTITLEMENTS, :quantity)
    change_column_null ENTITLEMENTS, :plan_id, true
    add_entitlement_constraints
    replace_order_index
  end

  def add_entitlement_constraints
    return if check_constraint_exists?(ENTITLEMENTS, name: 'chk_bt_billing_entitlements_one_item')

    add_check_constraint ENTITLEMENTS, '(plan_id IS NULL) <> (product_id IS NULL)', name: 'chk_bt_billing_entitlements_one_item'
  end

  def replace_order_index
    remove_index ENTITLEMENTS, name: 'idx_bt_billing_entitlements_order' if index_name_exists?(ENTITLEMENTS, 'idx_bt_billing_entitlements_order')
    unless index_name_exists?(ENTITLEMENTS, 'idx_bt_billing_entitlements_order_plan')
      add_index ENTITLEMENTS, %i[order_id plan_id], unique: true, where: 'order_id IS NOT NULL AND plan_id IS NOT NULL',
                                                    name: 'idx_bt_billing_entitlements_order_plan'
    end
    return if index_name_exists?(ENTITLEMENTS, 'idx_bt_billing_entitlements_order_product')

    add_index ENTITLEMENTS, %i[order_id product_id], unique: true, where: 'order_id IS NOT NULL AND product_id IS NOT NULL',
                                                     name: 'idx_bt_billing_entitlements_order_product'
  end
end
