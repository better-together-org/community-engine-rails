# frozen_string_literal: true

# Floors represent one or more rooms on a single level of a building.
class CreateBetterTogetherInfrastructureFloors < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :floors, prefix: :better_together_infrastructure do |t|
      t.bt_references :building, target_table: :better_together_infrastructure_buildings

      t.bt_community
      t.bt_creator
      t.bt_identifier
      t.bt_privacy
      t.bt_position

      t.integer :level, null: false, default: 0
      t.integer :rooms_count, default: 0, null: false
    end
  end
end
