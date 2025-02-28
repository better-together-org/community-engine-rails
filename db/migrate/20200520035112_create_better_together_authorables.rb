# frozen_string_literal: true

# Creates authorables table
class CreateBetterTogetherAuthorables < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :authorables do |t|
      t.bt_references :authorable,
                      null: false,
                      polymorphic: true,
                      index: {
                        name: 'by_authorable',
                        unique: true
                      }
    end
  end
end
