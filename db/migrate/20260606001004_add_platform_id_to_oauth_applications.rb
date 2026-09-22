# frozen_string_literal: true

# Phase 5 — OauthApplication isolation.
# Each platform has its own OAuth client registrations.
# Nullable; host platform is assigned to pre-existing applications.
class AddPlatformIdToOauthApplications < ActiveRecord::Migration[7.2]
  def change
    add_reference :better_together_oauth_applications, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true
  end
end
