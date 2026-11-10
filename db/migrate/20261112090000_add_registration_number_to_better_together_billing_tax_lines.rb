# frozen_string_literal: true

# The registration number of whoever collected a tax, copied onto its tax line when the order is placed so the
# number printed on an order is the one that was charged under. Encrypted, so the column is text with no default.
# Guarded so a re-run, or an interrupted earlier run, is a no-op.
class AddRegistrationNumberToBetterTogetherBillingTaxLines < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_tax_lines

  def up
    add_column TABLE, :registration_number, :text unless column_exists?(TABLE, :registration_number)
  end

  def down
    remove_column TABLE, :registration_number if column_exists?(TABLE, :registration_number)
  end
end
