# frozen_string_literal: true

# Add type column to users table for single-table inheritance (STI)
class AddTypeToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_users, :type, :string, default: nil
    add_index :better_together_users, :type

    # NOTE: For STI (single-table inheritance):
    # - Base class (User) has type = nil (no default needed, Rails handles this)
    # - Subclass (OauthUser) has type = 'BetterTogether::OauthUser'
    # All existing users are regular Users (type = nil), no migration needed
  end
end
