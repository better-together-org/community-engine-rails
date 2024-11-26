# frozen_string_literal: true

class CreateBetterTogetherGeographyCountryContinents < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :country_continents, prefix: 'better_together_geography' do |t|
      t.bt_references :country, table_prefix: 'better_together_geography',
                                index: { name: 'country_continent_by_country' }
      t.bt_references :continent, table_prefix: 'better_together_geography',
                                  index: { name: 'country_continent_by_continent' }
      t.index %i[country_id continent_id], unique: true, name: 'index_country_continents_on_country_and_continent'
    end
  end
end
