# frozen_string_literal: true

# Add table to store map data
class CreateBetterTogetherGeographyMaps < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :maps, prefix: :better_together_geography, id: :uuid do |t|
      t.bt_creator
      t.bt_identifier
      t.bt_locale
      t.bt_privacy
      t.bt_protected
    end
  end
end
