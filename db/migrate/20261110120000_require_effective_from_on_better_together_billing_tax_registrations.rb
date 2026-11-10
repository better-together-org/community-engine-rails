# frozen_string_literal: true

# A tax registration says from when it is in force, so it always has a start. An end stays optional: none means an
# ongoing registration. Existing rows without a start take the day they were made.
class RequireEffectiveFromOnBetterTogetherBillingTaxRegistrations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_tax_registrations

  def up
    return unless column_exists?(TABLE, :effective_from)

    execute "UPDATE #{TABLE} SET effective_from = created_at WHERE effective_from IS NULL"
    change_column_null TABLE, :effective_from, false
  end

  def down
    change_column_null TABLE, :effective_from, true if column_exists?(TABLE, :effective_from)
  end
end
