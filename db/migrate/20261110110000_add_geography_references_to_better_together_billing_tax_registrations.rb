# frozen_string_literal: true

# Links a tax registration to the geography records it is for, the same country and state records tax zones use,
# so a registration and the zones it collects for line up. country_iso and region_code stay as the keys tax is
# looked up by and are kept in step with the chosen records. Existing rows are linked by their codes.
class AddGeographyReferencesToBetterTogetherBillingTaxRegistrations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_tax_registrations
  REFERENCES = { country_id: :better_together_geography_countries, state_id: :better_together_geography_states }.freeze

  def up
    REFERENCES.each do |column, target|
      add_column TABLE, column, :uuid unless column_exists?(TABLE, column)
      index = "idx_bt_billing_tax_registrations_#{column}"
      add_index TABLE, column, name: index unless index_name_exists?(TABLE, index)
      add_foreign_key TABLE, target, column:, on_delete: :nullify unless foreign_key_exists?(TABLE, target, column:)
    end
    backfill
  end

  def down
    REFERENCES.each do |column, target|
      remove_foreign_key TABLE, target, column: column if foreign_key_exists?(TABLE, target, column: column)
      index = "idx_bt_billing_tax_registrations_#{column}"
      remove_index TABLE, name: index if index_name_exists?(TABLE, index)
      remove_column TABLE, column if column_exists?(TABLE, column)
    end
  end

  private

  def backfill
    execute <<~SQL.squish
      UPDATE #{TABLE} r SET country_id = c.id
      FROM better_together_geography_countries c
      WHERE r.country_id IS NULL AND upper(c.iso_code) = r.country_iso
    SQL
    execute <<~SQL.squish
      UPDATE #{TABLE} r SET state_id = s.id
      FROM better_together_geography_states s
      WHERE r.state_id IS NULL AND r.region_code IS NOT NULL AND upper(s.iso_code) = r.country_iso || '-' || r.region_code
    SQL
  end
end
