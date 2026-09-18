# frozen_string_literal: true

# Phase 6 — Platform isolation for ContactDetail children.
# All child tables inherit platform_id from their ContactDetail parent.
class AddPlatformIdToContactDetailChildren < ActiveRecord::Migration[7.2]
  def change
    %w[
      better_together_addresses
      better_together_email_addresses
      better_together_phone_numbers
      better_together_social_media_accounts
      better_together_website_links
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end
  end
end
