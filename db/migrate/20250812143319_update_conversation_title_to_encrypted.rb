# frozen_string_literal: true

# updates conversation title column to be stored as encrypted
class UpdateConversationTitleToEncrypted < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        run_engine_rake_task('better_together:migrate_data:unencrypted_conv_titles', file: 'tasks/data_migration.rake',
                                                                                     skip_when_empty: %i[better_together_conversations])
      end
    end
  end
end
