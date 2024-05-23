class CreateBetterTogetherGeographyContinents < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :continents, prefix: 'better_together_geography' do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_primary_community(:geography_continent)
      t.bt_slug
    end
  end
end
