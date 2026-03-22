# frozen_string_literal: true

# Adds creator_id to pages table
class AddCreatorToPages < ActiveRecord::Migration[7.2]
  def change
    return if column_exists? :better_together_pages, :creator_id

    add_column :better_together_pages, :creator_id, :uuid
    add_index :better_together_pages, :creator_id
    add_foreign_key :better_together_pages, :better_together_people, column: :creator_id
  end
end
