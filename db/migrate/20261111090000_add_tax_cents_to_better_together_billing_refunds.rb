# frozen_string_literal: true

# The part of a refund that is tax, pro-rated from the order's tax when the refund is recorded, so what was
# given back splits into net and tax. Guarded so a re-run, or an interrupted earlier run, is a no-op.
class AddTaxCentsToBetterTogetherBillingRefunds < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_refunds

  def up
    add_column TABLE, :tax_cents, :integer, default: 0, null: false unless column_exists?(TABLE, :tax_cents)
  end

  def down
    remove_column TABLE, :tax_cents if column_exists?(TABLE, :tax_cents)
  end
end
