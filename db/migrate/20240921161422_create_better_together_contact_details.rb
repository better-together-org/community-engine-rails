# frozen_string_literal: true

class CreateBetterTogetherContactDetails < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :contact_details do |t|
      t.bt_references :contactable, polymorphic: true, null: false
    end
  end
end
