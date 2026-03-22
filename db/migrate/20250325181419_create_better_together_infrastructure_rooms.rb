# frozen_string_literal: true

# Rooms are individual spatial units that make up a floor
class CreateBetterTogetherInfrastructureRooms < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :rooms, prefix: :better_together_infrastructure do |t|
      t.bt_references :floor, target_table: :better_together_infrastructure_floors
      t.bt_community
      t.bt_creator
      t.bt_identifier
      t.bt_privacy
    end
  end
end
