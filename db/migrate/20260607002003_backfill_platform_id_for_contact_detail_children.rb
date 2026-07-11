# frozen_string_literal: true

# Phase 6 — Backfill platform_id for ContactDetail children from their parent.
class BackfillPlatformIdForContactDetailChildren < ActiveRecord::Migration[7.2]
  def up
    # Addresses
    if column_exists?(:better_together_addresses, :platform_id)
      execute <<~SQL
        UPDATE better_together_addresses a
        SET    platform_id = cd.platform_id
        FROM   better_together_contact_details cd
        WHERE  a.contact_detail_id = cd.id
          AND  a.platform_id IS NULL
          AND  cd.platform_id IS NOT NULL
      SQL
    end

    # EmailAddresses
    if column_exists?(:better_together_email_addresses, :platform_id)
      execute <<~SQL
        UPDATE better_together_email_addresses ea
        SET    platform_id = cd.platform_id
        FROM   better_together_contact_details cd
        WHERE  ea.contact_detail_id = cd.id
          AND  ea.platform_id IS NULL
          AND  cd.platform_id IS NOT NULL
      SQL
    end

    # PhoneNumbers
    if column_exists?(:better_together_phone_numbers, :platform_id)
      execute <<~SQL
        UPDATE better_together_phone_numbers pn
        SET    platform_id = cd.platform_id
        FROM   better_together_contact_details cd
        WHERE  pn.contact_detail_id = cd.id
          AND  pn.platform_id IS NULL
          AND  cd.platform_id IS NOT NULL
      SQL
    end

    # SocialMediaAccounts
    if column_exists?(:better_together_social_media_accounts, :platform_id)
      execute <<~SQL
        UPDATE better_together_social_media_accounts sma
        SET    platform_id = cd.platform_id
        FROM   better_together_contact_details cd
        WHERE  sma.contact_detail_id = cd.id
          AND  sma.platform_id IS NULL
          AND  cd.platform_id IS NOT NULL
      SQL
    end

    # WebsiteLinks
    return unless column_exists?(:better_together_website_links, :platform_id)

    execute <<~SQL
      UPDATE better_together_website_links wl
      SET    platform_id = cd.platform_id
      FROM   better_together_contact_details cd
      WHERE  wl.contact_detail_id = cd.id
        AND  wl.platform_id IS NULL
        AND  cd.platform_id IS NOT NULL
    SQL
  end

  def down
    %w[
      better_together_addresses
      better_together_email_addresses
      better_together_phone_numbers
      better_together_social_media_accounts
      better_together_website_links
    ].each do |table|
      next unless column_exists?(table, :platform_id)

      execute "UPDATE #{table} SET platform_id = NULL"
    end
  end
end
