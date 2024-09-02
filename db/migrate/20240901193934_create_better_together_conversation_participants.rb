# frozen_string_literal: true

class CreateBetterTogetherConversationParticipants < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :conversation_participants do |t|
      t.bt_references :conversation, null: false
      t.bt_references :person, null: false
    end
  end
end
