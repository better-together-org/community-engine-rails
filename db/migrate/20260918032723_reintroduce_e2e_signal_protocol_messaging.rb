# frozen_string_literal: true

# Consolidated re-add of the Signal Protocol E2EE schema (originally
# 20260315020000..20260508000002, dropped by 20260911205151's removal
# migration). Written fresh rather than restoring the 6 original files,
# since their version numbers are already marked "up" in every host's
# schema_migrations and would no-op there. All steps are idempotent.
class ReintroduceE2eSignalProtocolMessaging < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  # rubocop:todo Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def up
    add_column :better_together_people, :identity_key_public, :text, comment: 'Signal identity public key (base64)' unless column_exists?(
      :better_together_people, :identity_key_public
    )
    add_column :better_together_people, :signed_prekey_id, :integer, comment: 'Current signed prekey ID' unless column_exists?(
      :better_together_people, :signed_prekey_id
    )
    add_column :better_together_people, :signed_prekey_public, :text, comment: 'Signed prekey public key (base64)' unless column_exists?(
      :better_together_people, :signed_prekey_public
    )
    add_column :better_together_people, :signed_prekey_sig, :text, comment: 'Signed prekey signature (base64)' unless column_exists?(
      :better_together_people, :signed_prekey_sig
    )
    add_column :better_together_people, :registration_id, :integer, comment: 'Signal registration ID' unless column_exists?(
      :better_together_people, :registration_id
    )
    unless index_name_exists?(:better_together_people, 'index_better_together_people_on_registration_id')
      add_index :better_together_people, :registration_id, unique: true, where: 'registration_id IS NOT NULL'
    end

    add_column :better_together_people, :key_backup_blob, :text unless column_exists?(:better_together_people, :key_backup_blob)
    add_column :better_together_people, :key_backup_salt, :text unless column_exists?(:better_together_people, :key_backup_salt)
    unless column_exists?(:better_together_people, :key_backup_updated_at)
      add_column :better_together_people, :key_backup_updated_at, :datetime
    end

    unless table_exists?(:better_together_one_time_prekeys)
      create_bt_table :one_time_prekeys do |t|
        t.bt_references :person, index: { name: 'bt_one_time_prekeys_by_person' }
        t.integer :key_id,     null: false,                 comment: 'Signal prekey ID (scoped to person)'
        t.text    :public_key, null: false,                 comment: 'Prekey public key (base64)'
        t.boolean :consumed,   default: false, null: false, comment: 'True after this key has been served once'
      end
    end
    unless index_exists?(:better_together_one_time_prekeys, %i[person_id key_id])
      add_index :better_together_one_time_prekeys, %i[person_id key_id], unique: true
    end
    unless index_exists?(:better_together_one_time_prekeys, %i[person_id consumed])
      add_index :better_together_one_time_prekeys, %i[person_id consumed]
    end

    unless column_exists?(:better_together_messages, :e2e_encrypted)
      add_column :better_together_messages, :e2e_encrypted, :boolean, default: false, null: false,
                                                                      comment: 'True when message content is E2E encrypted by the client'
    end
    unless column_exists?(:better_together_messages, :e2e_version)
      add_column :better_together_messages, :e2e_version, :integer, comment: 'E2E protocol version (1 = initial)'
    end
    unless column_exists?(:better_together_messages, :e2e_protocol)
      add_column :better_together_messages, :e2e_protocol, :string,
                 comment: 'Protocol identifier: signal_v1 (1:1) or sender_keys_v1 (group)'
    end
    unless index_name_exists?(:better_together_messages, 'index_better_together_messages_on_e2e_encrypted')
      add_index :better_together_messages, :e2e_encrypted, algorithm: :concurrently
    end

    return if column_exists?(:better_together_conversations, :sender_key_version)

    add_column :better_together_conversations, :sender_key_version, :integer, default: 0, null: false
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
