# frozen_string_literal: true

# Which tax a rate belongs to (GST/HST, PST, QST, RST, VAT or other), so a seller's report can keep the federal tax apart
# from the provincial ones: they are filed on different returns, with different administrators. The line keeps a copy of
# its rate's authority, like it keeps the rate itself, so a later change to the rate never rewrites a past sale.
class AddAuthorityToBetterTogetherBillingTaxRatesAndLines < ActiveRecord::Migration[7.2]
  TABLES = %i[better_together_billing_tax_rates better_together_billing_tax_lines].freeze
  BY_LABEL = { 'GST' => 'gst_hst', 'HST' => 'gst_hst', 'PST' => 'pst', 'QST' => 'qst', 'RST' => 'rst', 'VAT' => 'vat' }.freeze

  def up
    TABLES.each do |table|
      next unless table_exists?(table)

      add_column table, :authority, :string, null: false, default: 'other' unless column_exists?(table, :authority)
    end
    backfill
  end

  def down
    TABLES.each do |table|
      remove_column table, :authority if table_exists?(table) && column_exists?(table, :authority)
    end
  end

  private

  # Rows made before the column existed take it from their English label (the seeded labels are GST, HST, PST, QST and RST).
  def backfill
    TABLES.each do |table|
      next unless table_exists?(table) && table_exists?(:mobility_string_translations)

      type = table == TABLES.first ? 'BetterTogether::Billing::TaxRate' : 'BetterTogether::Billing::TaxLine'
      BY_LABEL.each do |label, authority|
        execute(<<~SQL.squish)
          UPDATE #{quote_table_name(table)} rows SET authority = #{quote(authority)}
          FROM mobility_string_translations t
          WHERE t.translatable_type = #{quote(type)} AND t.translatable_id = rows.id AND t.key = 'label' AND t.locale = 'en'
            AND UPPER(t.value) = #{quote(label)} AND rows.authority = 'other'
        SQL
      end
    end
  end
end
