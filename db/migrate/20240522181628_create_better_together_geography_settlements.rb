# frozen_string_literal: true

class CreateBetterTogetherGeographySettlements < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :settlements, prefix: :better_together_geography do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_community(:geography_settlement)
      t.bt_references :country, table_prefix: 'better_together_geography', optional: true
      t.bt_references :state, table_prefix: 'better_together_geography', optional: true
      t.bt_slug
    end
  end
end
