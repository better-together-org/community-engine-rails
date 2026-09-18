# frozen_string_literal: true

# Removes the Signal Protocol E2EE messaging feature's schema footprint.
#
# The feature (added 20260315020000..20260508000002) was pulled from the 0.11.0
# release pending further security hardening rather than shipped — see
# CHANGELOG.md and feature/e2e-signal-protocol-messaging-01100notes for the
# preserved implementation. Several production host apps already ran the
# original 6 migrations (they pin the CE gem to a commit on this branch, not a
# released tag), so this must actively clean up the columns/tables rather than
# rely on the original migration files simply being deleted. Guarded with
# if_exists/if_not_exists throughout so this is a no-op on any environment
# where a piece is already missing (e.g. hosts on an older ref that never
# picked up 20260508000002).
class RemoveE2eSignalProtocolMessaging < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  OLD_MESSAGES_E2E_INDEX = 'index_better_together_messages_on_e2e_encrypted'

  def up
    remove_index :better_together_messages, name: OLD_MESSAGES_E2E_INDEX, algorithm: :concurrently, if_exists: true

    remove_column :better_together_messages, :e2e_encrypted, if_exists: true
    remove_column :better_together_messages, :e2e_version, if_exists: true
    remove_column :better_together_messages, :e2e_protocol, if_exists: true

    remove_column :better_together_conversations, :sender_key_version, if_exists: true

    drop_table :better_together_one_time_prekeys, if_exists: true

    remove_column :better_together_people, :identity_key_public, if_exists: true
    remove_column :better_together_people, :signed_prekey_id, if_exists: true
    remove_column :better_together_people, :signed_prekey_public, if_exists: true
    remove_column :better_together_people, :signed_prekey_sig, if_exists: true
    remove_column :better_together_people, :registration_id, if_exists: true
    remove_column :better_together_people, :key_backup_blob, if_exists: true
    remove_column :better_together_people, :key_backup_salt, if_exists: true
    remove_column :better_together_people, :key_backup_updated_at, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
