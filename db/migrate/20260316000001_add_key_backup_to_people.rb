# frozen_string_literal: true

class AddKeyBackupToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_people, :key_backup_blob, :text
    add_column :better_together_people, :key_backup_salt, :text
    add_column :better_together_people, :key_backup_updated_at, :datetime
  end
end
