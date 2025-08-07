# frozen_string_literal: true

# Creates table for Comments
class CreateBetterTogetherComments < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :comments do |t|
      t.bt_references :commentable,
                      polymorphic: true,
                      null: false,
                      index: { name: 'bt_comments_on_commentable' }
      t.bt_creator

      t.text :content, null: false, default: ''
    end
  end
end
