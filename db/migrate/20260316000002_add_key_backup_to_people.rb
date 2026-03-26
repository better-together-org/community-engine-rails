# frozen_string_literal: true

# Adds passphrase-encrypted key backup columns to BetterTogether::Person.
# The server treats blob + salt as opaque strings; only the client can decrypt them.
class AddKeyBackupToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_people, :key_backup_blob, :text unless column_exists?(:better_together_people, :key_backup_blob)
    add_column :better_together_people, :key_backup_salt, :text unless column_exists?(:better_together_people, :key_backup_salt)
    add_column :better_together_people, :key_backup_updated_at, :datetime unless column_exists?(:better_together_people, :key_backup_updated_at)
  end
end
