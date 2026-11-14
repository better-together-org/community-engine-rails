# frozen_string_literal: true

# Which plans an add-on extends. An add-on with no rows here extends every primary plan of its platform. Guarded so a re-run, or an
# interrupted earlier run, is a no-op for what exists.
class CreateBetterTogetherBillingPlanAddOns < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:better_together_billing_plan_add_ons)

    create_bt_table :billing_plan_add_ons do |t|
      t.uuid :platform_id, null: false
      t.uuid :plan_id, null: false
      t.uuid :add_on_id, null: false
    end

    add_index :better_together_billing_plan_add_ons, %i[add_on_id plan_id], unique: true, name: 'idx_bt_billing_plan_add_ons_pair'
    add_index :better_together_billing_plan_add_ons, :plan_id, name: 'idx_bt_billing_plan_add_ons_plan'
    add_foreign_key :better_together_billing_plan_add_ons, :better_together_billing_plans, column: :plan_id
    add_foreign_key :better_together_billing_plan_add_ons, :better_together_billing_plans, column: :add_on_id
  end

  def down
    drop_table :better_together_billing_plan_add_ons if table_exists?(:better_together_billing_plan_add_ons)
  end
end
