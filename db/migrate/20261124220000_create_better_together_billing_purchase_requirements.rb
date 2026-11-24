# frozen_string_literal: true

# A rule that a purchasable may only be bought by someone who meets a prerequisite: the dependent (any registered
# purchasable) and either one specific prerequisite purchasable or a kind of them ("plan" is any primary plan).
# How it is met, whether it is required alongside the others, and what happens to the dependent when the
# prerequisite ends are settings on the rule. Guarded so a re-run is a no-op.
class CreateBetterTogetherBillingPurchaseRequirements < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_purchase_requirements

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_purchase_requirements do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_purchase_requirements_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :dependent_type, null: false
      t.uuid :dependent_id, null: false
      t.string :prerequisite_type
      t.uuid :prerequisite_id
      t.string :prerequisite_kind
      t.string :met_by, null: false, default: 'either'
      t.boolean :required, null: false, default: false
      t.string :on_prerequisite_end, null: false, default: 'keep'
    end

    add_index TABLE, %i[dependent_type dependent_id], name: 'idx_bt_billing_purchase_requirements_dependent'
    add_index TABLE, %i[prerequisite_type prerequisite_id], name: 'idx_bt_billing_purchase_requirements_prerequisite'
    add_index TABLE, %i[dependent_type dependent_id prerequisite_type prerequisite_id], unique: true,
                                                                                        where: 'prerequisite_id IS NOT NULL',
                                                                                        name: 'idx_bt_billing_purchase_requirements_one_specific'
    add_index TABLE, %i[dependent_type dependent_id prerequisite_kind], unique: true, where: 'prerequisite_kind IS NOT NULL',
                                                                        name: 'idx_bt_billing_purchase_requirements_one_kind'
    add_check_constraint TABLE, '(prerequisite_id IS NULL) <> (prerequisite_kind IS NULL)',
                         name: 'chk_bt_billing_purchase_requirements_one_target'
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end
end
