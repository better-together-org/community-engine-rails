# frozen_string_literal: true

# No support for Fascist platforms
class DeleteExistingTwixSocialMediaAccounts < ActiveRecord::Migration[7.1]
  # Migration-local model: the app model scopes by platform_id, which does not exist yet here.
  class MigrationSocialMediaAccount < ActiveRecord::Base
    self.table_name = 'better_together_social_media_accounts'
  end

  def up
    return unless table_exists?(:better_together_social_media_accounts)
    return unless column_exists?(:better_together_social_media_accounts, :platform)

    MigrationSocialMediaAccount.where(platform: %w[X Twitter]).delete_all
  end

  def down; end
end
