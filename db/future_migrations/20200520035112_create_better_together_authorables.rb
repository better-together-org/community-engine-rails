# frozen_string_literal: true

# Creates authorables table
class CreateBetterTogetherAuthorables < ActiveRecord::Migration[6.0]
  def change # rubocop:todo Metrics/MethodLength
    create_table :better_together_authorables do |t|
      t.string :id,
               null: false,
               index: {
                 name: 'authorable_by_id',
                 unique: true
               },
               limit: 50
      t.references  :authorable,
                    null: false,
                    polymorphic: true,
                    index: {
                      name: 'by_authorable',
                      unique: true
                    }

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end
  end
end
