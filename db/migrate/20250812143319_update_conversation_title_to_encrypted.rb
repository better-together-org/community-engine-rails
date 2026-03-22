# frozen_string_literal: true

# updates conversation title column to be stored as encrypted
class UpdateConversationTitleToEncrypted < ActiveRecord::Migration[7.1]
  def change
    reversible do |dir|
      dir.up do
        load 'tasks/data_migration.rake'
        Rake::Task['better_together:migrate_data:unencrypted_conv_titles'].invoke
      end
    end
  end
end
