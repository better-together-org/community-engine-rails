# frozen_string_literal: true

# A plan sold only as an extra on another plan's order (a registration fee, a one-off setup), never by itself or in the catalog.
class AddAddOnToBetterTogetherBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans

  def up
    return unless table_exists?(TABLE)

    add_column TABLE, :add_on, :boolean, null: false, default: false unless column_exists?(TABLE, :add_on)
  end

  def down
    return unless table_exists?(TABLE)

    remove_column TABLE, :add_on if column_exists?(TABLE, :add_on)
  end
end
