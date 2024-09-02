# frozen_string_literal: true

# Creates the conversations table used to group conversations for participants
class CreateBetterTogetherConversations < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :conversations do |t|
      t.string :title, null: false
      t.bt_references :creator, target_table: :better_together_people, null: false
    end
  end
end
