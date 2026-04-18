# frozen_string_literal: true

class AddContentScreeningToBetterTogetherInboundEmailMessages < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_inbound_email_messages, bulk: true do |t|
      t.string :screening_state, null: false, default: 'pending'
      t.string :screening_verdict
      t.text :content_screening_summary
      t.text :content_security_records_json
    end

    add_index :better_together_inbound_email_messages, :screening_state
    add_index :better_together_inbound_email_messages, :screening_verdict
  end
end
