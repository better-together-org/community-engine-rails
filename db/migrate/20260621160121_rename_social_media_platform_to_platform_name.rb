# frozen_string_literal: true

class RenameSocialMediaPlatformToPlatformName < ActiveRecord::Migration[7.2]
  def up
    return if column_exists?(:better_together_social_media_accounts, :platform_name)

    rename_column :better_together_social_media_accounts, :platform, :platform_name
  end

  def down
    return unless column_exists?(:better_together_social_media_accounts, :platform_name)

    rename_column :better_together_social_media_accounts, :platform_name, :platform
  end
end
