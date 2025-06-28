# frozen_string_literal: true

# Ensure that all privacy columns are defaulted to private, as "unlisted" has been removed
class EnsureAllPrivacyColumnsDefaultToPrivate < ActiveRecord::Migration[7.1]
  def up
    load ::BetterTogether::Engine.root.join('lib', 'tasks', 'data_migration.rake').to_s

    begin
      Rake::Task['better_together:migrate_data:set_privacy_default_to_private'].invoke
    rescue RuntimeError
      Rake::Task['app:better_together:migrate_data:set_privacy_default_to_private'].invoke
    end
  end

  def down; end
end
