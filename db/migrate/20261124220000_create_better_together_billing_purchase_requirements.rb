# frozen_string_literal: true

# A rule that a purchasable may only be bought by someone who meets a prerequisite: the dependent (any registered
# purchasable) and either one specific prerequisite purchasable or a kind of them ("plan" is any primary plan).
# How it is met, whether it is required alongside the others, and what happens to the dependent when the
# prerequisite ends are settings on the rule. Each step is guarded, so a retry
# after a partial run repairs the table instead of skipping what is missing.
class CreateBetterTogetherBillingPurchaseRequirements < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_purchase_requirements
  INDEXES = {
    'idx_bt_billing_purchase_requirements_dependent' => [%i[dependent_type dependent_id], {}],
    'idx_bt_billing_purchase_requirements_prerequisite' => [%i[prerequisite_type prerequisite_id], {}],
    'idx_bt_billing_purchase_requirements_one_specific' =>
      [%i[dependent_type dependent_id prerequisite_type prerequisite_id], { unique: true, where: 'prerequisite_id IS NOT NULL' }],
    'idx_bt_billing_purchase_requirements_one_kind' =>
      [%i[dependent_type dependent_id prerequisite_kind], { unique: true, where: 'prerequisite_kind IS NOT NULL' }]
  }.freeze
  CHECK = 'chk_bt_billing_purchase_requirements_one_target'

  def up
    create_table_unless_present
    add_missing_indexes
    add_missing_check
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def create_table_unless_present
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
  end

  def add_missing_indexes
    INDEXES.each do |name, (columns, options)|
      add_index TABLE, columns, name:, **options unless index_name_exists?(TABLE, name)
    end
  end

  def add_missing_check
    return if check_constraint_exists?(TABLE, name: CHECK)

    add_check_constraint TABLE, '(prerequisite_id IS NULL) <> (prerequisite_kind IS NULL)', name: CHECK
  end
end
