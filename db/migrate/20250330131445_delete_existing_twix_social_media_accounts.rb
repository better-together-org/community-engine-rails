# frozen_string_literal: true

# No support for Fascist platforms
# Uses SQL, not the current model, so it also runs from an empty database where the
# model's later columns (platform_id) do not exist yet.
class DeleteExistingTwixSocialMediaAccounts < ActiveRecord::Migration[7.1]
  TABLE = :better_together_social_media_accounts

  def up
    return unless table_exists?(TABLE) && column_exists?(TABLE, :platform)

    execute("DELETE FROM #{TABLE} WHERE platform IN ('X', 'Twitter')")
  end

  def down; end
end
