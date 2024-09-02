# frozen_string_literal: true

# Creates a join table to link people to conversations as participants
class CreateBetterTogetherConversationParticipants < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :conversation_participants do |t|
      t.bt_references :conversation, null: false
      t.bt_references :person, null: false
    end
  end
end
