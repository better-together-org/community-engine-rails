# frozen_string_literal: true

class CreateBetterTogetherGeographyRegions < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :regions, prefix: :better_together_geography do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_community(:geography_region)
      t.bt_references :country, table_prefix: 'better_together_geography', optional: true
      t.bt_references :state, table_prefix: 'better_together_geography', optional: true
      t.bt_slug
      t.string :type, null: false, default: 'BetterTogether::Geography::Region'
    end
  end
end
