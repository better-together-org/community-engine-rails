# frozen_string_literal: true

class CreateBetterTogetherChecklists < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change
    create_bt_table :checklists do |t|
      t.bt_identifier
      t.bt_creator
      t.bt_protected
      t.bt_privacy
      # When true, items must be completed in order (by position)
      t.boolean :directional, null: false, default: false
    end
  end
end
