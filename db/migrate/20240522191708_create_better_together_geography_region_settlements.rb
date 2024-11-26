# frozen_string_literal: true

class CreateBetterTogetherGeographyRegionSettlements < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :region_settlements, prefix: :better_together_geography do |t|
      t.bt_protected
      t.bt_references :region, table_prefix: 'better_together_geography',
                               index: { name: 'bt_region_settlement_by_region' }
      t.bt_references :settlement, table_prefix: 'better_together_geography',
                                   index: { name: 'bt_region_settlement_by_settlement' }
    end
  end
end
