# frozen_string_literal: true

class CreateBetterTogetherGeographyStates < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :states, prefix: 'better_together_geography' do |t|
      t.bt_identifier
      t.bt_location(char_length: 5)
      t.bt_protected
      t.bt_community(:geography_state)
      t.bt_references :country, table_prefix: 'better_together_geography'
      t.bt_slug
    end
  end
end
