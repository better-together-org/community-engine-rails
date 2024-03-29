# frozen_string_literal: true

# Creates authorships table
class CreateBetterTogetherAuthorships < ActiveRecord::Migration[6.0]
  def change # rubocop:todo Metrics/MethodLength
    create_table :better_together_authorships do |t|
      t.string :id,
               null: false,
               index: {
                 name: 'authorship_by_id',
                 unique: true
               },
               limit: 50
      t.references  :authorable,
                    null: false,
                    index: {
                      name: 'by_authorship_authorable'
                    }
      t.references  :author,
                    null: false,
                    index: {
                      name: 'by_authorship_author'
                    }
      t.integer :sort_order,
                index: {
                  name: 'by_authorship_sort_order'
                }

      t.integer :lock_version, null: false, default: 0
      t.timestamps null: false
    end

    add_foreign_key :better_together_authorships,
                    :better_together_authors,
                    column: :author_id

    add_foreign_key :better_together_authorships,
                    :better_together_authorables,
                    column: :authorable_id
  end
end
