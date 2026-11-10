# frozen_string_literal: true

# The text people read in billing (plan, promotion and tax names, what an order's lines and tax lines say) now lives in
# Mobility translations, one value per language, instead of one plain column. Billing has not been deployed anywhere,
# so there is nothing to carry over. The order also remembers the language it was placed in and, when a steward asks
# for it, the language its documents are made in.
class LocalizeBetterTogetherBillingText < ActiveRecord::Migration[7.2]
  COLUMNS = {
    better_together_billing_plans: %i[name description],
    better_together_billing_promotions: %i[name],
    better_together_billing_tax_categories: %i[name],
    better_together_billing_tax_zones: %i[name],
    better_together_billing_tax_rates: %i[label],
    better_together_billing_tax_lines: %i[label],
    better_together_billing_line_items: %i[description],
    better_together_billing_order_agreement_acceptances: %i[agreement_title]
  }.freeze

  def up
    COLUMNS.each do |table, columns|
      next unless table_exists?(table)

      columns.each { |column| remove_column table, column if column_exists?(table, column) }
    end

    add_column :better_together_billing_orders, :placed_locale, :string unless column_exists?(:better_together_billing_orders, :placed_locale)
    add_column :better_together_billing_orders, :document_locale, :string unless column_exists?(:better_together_billing_orders,
                                                                                                :document_locale)
  end

  def down
    remove_column :better_together_billing_orders, :document_locale if column_exists?(:better_together_billing_orders, :document_locale)
    remove_column :better_together_billing_orders, :placed_locale if column_exists?(:better_together_billing_orders, :placed_locale)

    { better_together_billing_plans: { name: :string, description: :text },
      better_together_billing_promotions: { name: :string }, better_together_billing_tax_categories: { name: :string },
      better_together_billing_tax_zones: { name: :string }, better_together_billing_tax_rates: { label: :string },
      better_together_billing_tax_lines: { label: :string }, better_together_billing_line_items: { description: :string },
      better_together_billing_order_agreement_acceptances: { agreement_title: :string } }.each do |table, columns|
      columns.each { |column, type| add_column table, column, type unless column_exists?(table, column) }
    end
  end
end
