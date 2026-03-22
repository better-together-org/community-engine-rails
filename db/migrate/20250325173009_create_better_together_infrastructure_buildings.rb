# frozen_string_literal: true

# Creates db table for buildings
class CreateBetterTogetherInfrastructureBuildings < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :buildings, prefix: :better_together_infrastructure do |t|
      t.string :type, null: false, default: 'BetterTogether::Infrastructure::Building'
      t.bt_community
      t.bt_creator
      t.bt_identifier
      t.bt_privacy

      t.integer :floors_count, default: 0, null: false
      t.integer :rooms_count, default: 0, null: false
    end
  end
end
