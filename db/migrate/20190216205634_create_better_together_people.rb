# frozen_string_literal: true

# Creates people table
class CreateBetterTogetherPeople < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :people do |t|
      t.bt_identifier
      t.bt_primary_community(:person)
      t.bt_slug
    end
  end
end
