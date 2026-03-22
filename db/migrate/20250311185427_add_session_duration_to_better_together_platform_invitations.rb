# frozen_string_literal: true

# Add session duration to BetterTogether::PlatformInvitation
class AddSessionDurationToBetterTogetherPlatformInvitations < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_platform_invitations, :session_duration_mins, :integer, default: 30, null: false
  end
end
