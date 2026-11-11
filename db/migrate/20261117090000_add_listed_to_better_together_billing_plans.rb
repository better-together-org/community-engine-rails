# frozen_string_literal: true

# Whether a plan is shown in the public catalog. A plan is bought by going to its checkout; listing it is a separate choice
# a steward makes, so plans that existed before this column stay unlisted until someone says otherwise.
class AddListedToBetterTogetherBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :listed, :boolean, null: false, default: false unless column_exists?(TABLE, :listed)
    add_index TABLE, :listed, name: 'idx_bt_billing_plans_listed' unless index_name_exists?(TABLE, 'idx_bt_billing_plans_listed')
  end

  def down
    return unless table_exists?(TABLE)

    remove_index TABLE, name: 'idx_bt_billing_plans_listed' if index_name_exists?(TABLE, 'idx_bt_billing_plans_listed')
    remove_column TABLE, :listed if column_exists?(TABLE, :listed)
  end
end
