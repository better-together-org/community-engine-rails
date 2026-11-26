# frozen_string_literal: true

# What a product includes is one thing, whether the product is a plan or not, so the table loses "plan" from its name.
class RenamePlanGrantsToGrants < ActiveRecord::Migration[7.2]
  def up
    return if table_exists?(:better_together_billing_grants) || !table_exists?(:better_together_billing_plan_grants)

    rename_table :better_together_billing_plan_grants, :better_together_billing_grants
  end

  def down
    return if table_exists?(:better_together_billing_plan_grants) || !table_exists?(:better_together_billing_grants)

    rename_table :better_together_billing_grants, :better_together_billing_plan_grants
  end
end
