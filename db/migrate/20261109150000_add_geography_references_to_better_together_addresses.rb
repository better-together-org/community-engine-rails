# frozen_string_literal: true

# Optional links from an address to the geography records it was entered against.
# The string columns stay as the free-text fallback when no record exists.
class AddGeographyReferencesToBetterTogetherAddresses < ActiveRecord::Migration[7.2]
  TABLE = :better_together_addresses
  REFERENCES = {
    country_id: :better_together_geography_countries,
    state_id: :better_together_geography_states,
    settlement_id: :better_together_geography_settlements
  }.freeze

  def up
    REFERENCES.each do |column, target|
      add_column TABLE, column, :uuid unless column_exists?(TABLE, column)
      index = "index_bt_addresses_on_#{column}"
      add_index TABLE, column, name: index unless index_name_exists?(TABLE, index)
      next if foreign_key_exists?(TABLE, target, column:)

      add_foreign_key TABLE, target, column:, on_delete: :nullify
    end
  end

  def down
    REFERENCES.each do |column, target|
      remove_foreign_key(TABLE, target, column: column) if foreign_key_exists?(TABLE, target, column: column)
      index = "index_bt_addresses_on_#{column}"
      remove_index TABLE, name: index if index_name_exists?(TABLE, index)
      remove_column TABLE, column if column_exists?(TABLE, column)
    end
  end
end
