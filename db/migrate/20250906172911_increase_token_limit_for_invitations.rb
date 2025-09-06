# frozen_string_literal: true

class IncreaseTokenLimitForInvitations < ActiveRecord::Migration[7.1]
  def up
    # Increase token column limit from 24 to 64 characters to support longer, more secure tokens
    change_column :better_together_invitations, :token, :string, limit: 64, null: false
    change_column :better_together_platform_invitations, :token, :string, limit: 64, null: false
  end

  def down
    # Revert back to 24 character limit (note: this could cause data loss if tokens are longer)
    change_column :better_together_invitations, :token, :string, limit: 24, null: false
    change_column :better_together_platform_invitations, :token, :string, limit: 24, null: false
  end
end
