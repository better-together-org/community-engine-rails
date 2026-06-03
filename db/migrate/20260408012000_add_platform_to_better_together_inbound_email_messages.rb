# frozen_string_literal: true

class AddPlatformToBetterTogetherInboundEmailMessages < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_inbound_email_messages,
                  :platform,
                  type: :uuid,
                  foreign_key: { to_table: :better_together_platforms }
  end
end
