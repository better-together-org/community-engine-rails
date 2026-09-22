# frozen_string_literal: true

# Ensure that all privacy columns are defaulted to private, as "unlisted" has been removed
class EnsureAllPrivacyColumnsDefaultToPrivate < ActiveRecord::Migration[7.1]
  PRIVACY_TABLES = %i[
    better_together_posts
    better_together_communities
    better_together_platforms
    better_together_pages
    better_together_email_addresses
    better_together_phone_numbers
    better_together_addresses
    better_together_social_media_accounts
    better_together_website_links
    better_together_people
    better_together_content_blocks
    better_together_seeds
    better_together_calendars
    better_together_geography_maps
    better_together_places
    better_together_infrastructure_buildings
    better_together_infrastructure_floors
    better_together_infrastructure_rooms
    better_together_uploads
    better_together_events
    better_together_agreements
    better_together_calls_for_interest
  ].freeze

  def up
    PRIVACY_TABLES.each do |table_name|
      next unless table_exists?(table_name)
      next unless column_exists?(table_name, :privacy)

      change_column_default table_name, :privacy, 'private'
    end
  end

  def down; end
end
