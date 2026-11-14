# frozen_string_literal: true

# Invitations and OAuth records created before platform binding have no platform. Every such row
# was issued by the host platform (the only platform with accounts and sign in), so bind them to it
# rather than refusing them at runtime. Other platform rows are external (OAuth providers, federation).
class BackfillHostPlatformOnInvitationsAndOauth < ActiveRecord::Migration[7.1]
  TABLES = %i[
    better_together_invitations
    better_together_oauth_applications
    better_together_oauth_access_tokens
    better_together_oauth_access_grants
  ].freeze

  def up
    host_id = select_value('SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1')
    return unless host_id

    TABLES.each do |table|
      next unless table_exists?(table) && column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = #{quote(host_id)} WHERE platform_id IS NULL"
    end
  end

  def down; end
end
