# frozen_string_literal: true

# Creates table for spaces
class CreateGeographySpaces < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :spaces, prefix: :better_together_geography do |t|
      t.bt_creator
      t.bt_identifier
      t.float :elevation, precision: 10, scale: 6
      t.float :latitude, precision: 10, scale: 6
      t.float :longitude, precision: 10, scale: 6
      t.jsonb :properties, default: {}
      t.jsonb :metadata, default: {}
    end
  end
end
