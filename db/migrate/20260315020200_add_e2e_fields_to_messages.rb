# frozen_string_literal: true

# Adds E2E encryption flag and metadata columns to BetterTogether::Message.
# When e2e_encrypted is true, the ActionText :content body holds an opaque
# Signal Protocol ciphertext blob; the server never decrypts it.
class AddE2eFieldsToMessages < ActiveRecord::Migration[7.2]
  def change
    unless column_exists?(
      :better_together_messages, :e2e_encrypted
    )
      add_column :better_together_messages, :e2e_encrypted, :boolean, default: false, null: false,
                                                                      comment: 'True when message content is E2E encrypted by the client'
    end
    unless column_exists?(:better_together_messages, :e2e_version)
      add_column :better_together_messages, :e2e_version, :integer,
                 comment: 'E2E protocol version (1 = initial)'
    end
    unless column_exists?(:better_together_messages,
                          :e2e_protocol)
      add_column :better_together_messages, :e2e_protocol, :string,
                 comment: 'Protocol identifier: signal_v1 (1:1) or sender_keys_v1 (group)'
    end

    add_index :better_together_messages, :e2e_encrypted unless index_name_exists?(:better_together_messages,
                                                                                  'index_better_together_messages_on_e2e_encrypted')
  end
end
