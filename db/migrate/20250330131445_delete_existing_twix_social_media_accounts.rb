# frozen_string_literal: true

# No support for Fascist platforms
class DeleteExistingTwixSocialMediaAccounts < ActiveRecord::Migration[7.1]
  def up
    twix = BetterTogether::SocialMediaAccount.where(platform: %w[X Twitter])

    twix.destroy_all if twix.exists?
  end

  def down; end
end
