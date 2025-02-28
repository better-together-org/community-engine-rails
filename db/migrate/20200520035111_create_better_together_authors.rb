# frozen_string_literal: true

# Creates authors table
class CreateBetterTogetherAuthors < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :authors do |t|
      t.bt_references :author,
                      null: false,
                      polymorphic: true,
                      index: {
                        name: 'by_author',
                        unique: true
                      }
    end
  end
end
