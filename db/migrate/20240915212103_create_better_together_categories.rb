# frozen_string_literal: true

class CreateBetterTogetherCategories < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :categories do |t|
      t.bt_identifier
      t.bt_slug
      t.bt_position
      t.bt_protected

      t.string :type, null: false, default: 'BetterTogether::Category'
    end
  end
end
