class MigrateUnencryptedMessageContentAndDropColumn < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        load 'tasks/data_migration.rake'
        Rake::Task['better_together:migrate_data:unencrypted_messages'].invoke

        remove_column :better_together_messages, :content, if_exists: true
      end
    end
  end
end
