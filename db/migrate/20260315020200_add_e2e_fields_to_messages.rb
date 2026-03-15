# frozen_string_literal: true

# Adds E2E encryption flag and metadata columns to BetterTogether::Message.
# When e2e_encrypted is true, the ActionText :content body holds an opaque
# Signal Protocol ciphertext blob; the server never decrypts it.
class AddE2eFieldsToMessages < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_messages, :e2e_encrypted, :boolean, default: false, null: false,
               comment: 'True when message content is E2E encrypted by the client'
    add_column :better_together_messages, :e2e_version,   :integer,
               comment: 'E2E protocol version (1 = initial)'
    add_column :better_together_messages, :e2e_protocol,  :string,
               comment: 'Protocol identifier: signal_v1 (1:1) or sender_keys_v1 (group)'

    add_index :better_together_messages, :e2e_encrypted
  end
end
