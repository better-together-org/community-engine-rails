# frozen_string_literal: true

# Creates authorships table
class CreateBetterTogetherAuthorships < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :authorships do |t|
      t.bt_position
      t.bt_references :authorable,
                      null: false,
                      polymorphic: true,
                      index: {
                        name: 'by_authorship_authorable'
                      }
      t.bt_references :author,
                      null: false,
                      target_table: 'better_together_people',
                      index: {
                        name: 'by_authorship_author'
                      }
    end
  end
end
