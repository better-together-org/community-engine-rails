# frozen_string_literal: true

class CreateBetterTogetherSitemaps < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :sitemaps do |t|
      t.bt_references :platform,
                      null: false,
                      index: { unique: true, name: 'unique_sitemaps_platform' }
    end
  end
end
