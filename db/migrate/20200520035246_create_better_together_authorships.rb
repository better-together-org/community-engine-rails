# frozen_string_literal: true

# Creates authorships table
class CreateBetterTogetherAuthorships < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :authorships do |t|
      t.bt_position
      t.bt_references :authorable,
                      null: false,
                      index: {
                        name: 'by_authorship_authorable'
                      }
      t.bt_references :author,
                      null: false,
                      index: {
                        name: 'by_authorship_author'
                      }
    end

    add_foreign_key :better_together_authorships,
                    :better_together_authors,
                    column: :author_id,
                    name: "authorships_on_author_id"

    add_foreign_key :better_together_authorships,
                    :better_together_authorables,
                    column: :authorable_id,
                    name: "authorships_on_authorable_id"
  end
end
