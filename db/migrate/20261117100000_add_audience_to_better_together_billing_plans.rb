# frozen_string_literal: true

# Who may see and buy a plan. Both off means anyone; either on limits it to people who qualify as that (any one is enough).
class AddAudienceToBetterTogetherBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans
  COLUMNS = %i[restricted_to_members restricted_to_subscribers].freeze

  def up
    return unless table_exists?(TABLE)

    COLUMNS.each { |name| add_column TABLE, name, :boolean, null: false, default: false unless column_exists?(TABLE, name) }
  end

  def down
    return unless table_exists?(TABLE)

    COLUMNS.each { |name| remove_column TABLE, name if column_exists?(TABLE, name) }
  end
end
