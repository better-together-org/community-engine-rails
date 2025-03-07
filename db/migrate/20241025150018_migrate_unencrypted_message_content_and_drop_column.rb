# frozen_string_literal: true

# Runs rake task to migrate existing message contents to encrypted message contents as encrypted rich texts
class MigrateUnencryptedMessageContentAndDropColumn < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        load 'tasks/data_migration.rake'
        Rake::Task['better_together:migrate_data:unencrypted_messages'].invoke
      end
    end
  end
end
