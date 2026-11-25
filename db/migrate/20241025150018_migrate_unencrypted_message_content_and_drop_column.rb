# frozen_string_literal: true

# Runs rake task to migrate existing message contents to encrypted message contents as encrypted rich texts
class MigrateUnencryptedMessageContentAndDropColumn < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        run_engine_rake_task('better_together:migrate_data:unencrypted_messages', file: 'tasks/data_migration.rake',
                                                                                  skip_when_empty: %i[better_together_messages])
      end
    end
  end
end
