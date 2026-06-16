# frozen_string_literal: true

# Phase 10 — Backfill extended isolation: Communication, Safety, PII
class BackfillPlatformIdForPhase10Extended < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up # rubocop:disable Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity,Metrics/MethodLength
    # Step 1: WebhookEndpoints from creator (person) → community → platform
    if column_exists?(:better_together_webhook_endpoints, :platform_id)
      execute <<~SQL
        UPDATE better_together_webhook_endpoints we
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  we.person_id = p.id
          AND  we.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL
    end

    # Step 2: WebhookDeliveries from webhook_endpoint
    if column_exists?(:better_together_webhook_deliveries, :platform_id)
      execute <<~SQL
        UPDATE better_together_webhook_deliveries wd
        SET    platform_id = we.platform_id
        FROM   better_together_webhook_endpoints we
        WHERE  wd.webhook_endpoint_id = we.id
          AND  wd.platform_id IS NULL
          AND  we.platform_id IS NOT NULL
      SQL
    end

    # Step 3: InboundEmailMessages — backfill nulls from community/platform context
    if column_exists?(:better_together_inbound_email_messages, :platform_id)
      # Backfill from target (polymorphic) if it's community-scoped
      execute <<~SQL
        UPDATE better_together_inbound_email_messages iem
        SET    platform_id = c.platform_id
        FROM   better_together_communities c
        WHERE  iem.target_type = 'BetterTogether::Community'
          AND  iem.target_id = c.id
          AND  iem.platform_id IS NULL
          AND  c.platform_id IS NOT NULL
      SQL

      # Host platform fallback for remaining nulls
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_inbound_email_messages
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 4: Reports from reportable object's platform (Posts, Pages, Events, etc.)
    if column_exists?(:better_together_reports, :platform_id)
      # Posts
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = p.platform_id
        FROM   better_together_posts p
        WHERE  r.reportable_type = 'BetterTogether::Post'
          AND  r.reportable_id = p.id
          AND  r.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL

      # Pages
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = pa.platform_id
        FROM   better_together_pages pa
        WHERE  r.reportable_type = 'BetterTogether::Page'
          AND  r.reportable_id = pa.id
          AND  r.platform_id IS NULL
          AND  pa.platform_id IS NOT NULL
      SQL

      # Events
      execute <<~SQL
        UPDATE better_together_reports r
        SET    platform_id = e.platform_id
        FROM   better_together_events e
        WHERE  r.reportable_type = 'BetterTogether::Event'
          AND  r.reportable_id = e.id
          AND  r.platform_id IS NULL
          AND  e.platform_id IS NOT NULL
      SQL

      # Host platform fallback
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_reports
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 5: Content security subjects from subject (polymorphic) → platform context
    if column_exists?(:better_together_content_security_subjects, :platform_id)
      # Posts
      execute <<~SQL
        UPDATE better_together_content_security_subjects css
        SET    platform_id = p.platform_id
        FROM   better_together_posts p
        WHERE  css.subject_type = 'BetterTogether::Post'
          AND  css.subject_id = p.id
          AND  css.platform_id IS NULL
          AND  p.platform_id IS NOT NULL
      SQL

      # Pages
      execute <<~SQL
        UPDATE better_together_content_security_subjects css
        SET    platform_id = pa.platform_id
        FROM   better_together_pages pa
        WHERE  css.subject_type = 'BetterTogether::Page'
          AND  css.subject_id = pa.id
          AND  css.platform_id IS NULL
          AND  pa.platform_id IS NOT NULL
      SQL

      # Host platform fallback
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_content_security_subjects
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
    end

    # Step 6: ContentSecurityItems from subject
    if column_exists?(:better_together_content_security_items, :platform_id)
      execute <<~SQL
        UPDATE better_together_content_security_items csi
        SET    platform_id = css.platform_id
        FROM   better_together_content_security_subjects css
        WHERE  csi.subject_id = css.id
          AND  csi.platform_id IS NULL
          AND  css.platform_id IS NOT NULL
      SQL
    end

    # Step 7: ContentSecurityFindings from item
    if column_exists?(:better_together_content_security_findings, :platform_id)
      execute <<~SQL
        UPDATE better_together_content_security_findings csf
        SET    platform_id = csi.platform_id
        FROM   better_together_content_security_items csi
        WHERE  csf.item_id = csi.id
          AND  csf.platform_id IS NULL
          AND  csi.platform_id IS NOT NULL
      SQL
    end

    # Step 8: ContentSecurityScanEvents from item
    if column_exists?(:better_together_content_security_scan_events, :platform_id)
      execute <<~SQL
        UPDATE better_together_content_security_scan_events csse
        SET    platform_id = csi.platform_id
        FROM   better_together_content_security_items csi
        WHERE  csse.item_id = csi.id
          AND  csse.platform_id IS NULL
          AND  csi.platform_id IS NOT NULL
      SQL
    end

    # Step 9: ContactDetails (polymorphic) — inherit from contactable if Person
    if column_exists?(:better_together_contact_details, :platform_id)
      execute <<~SQL
        UPDATE better_together_contact_details cd
        SET    platform_id = ppm.joinable_id
        FROM   better_together_people p
        JOIN   better_together_person_platform_memberships ppm
          ON   p.id = ppm.member_id
        WHERE  cd.contactable_type = 'BetterTogether::Person'
          AND  cd.contactable_id = p.id
          AND  cd.platform_id IS NULL
          AND  ppm.joinable_id IS NOT NULL
      SQL
    end

    # Step 10: Addresses, EmailAddresses, PhoneNumbers, SocialMediaAccounts, WebsiteLinks from contact_detail
    %w[
      better_together_addresses
      better_together_email_addresses
      better_together_phone_numbers
      better_together_social_media_accounts
      better_together_website_links
    ].each do |child_table|
      next unless column_exists?(child_table, :platform_id)

      execute <<~SQL
        UPDATE #{child_table} child
        SET    platform_id = cd.platform_id
        FROM   better_together_contact_details cd
        WHERE  child.contact_detail_id = cd.id
          AND  child.platform_id IS NULL
          AND  cd.platform_id IS NOT NULL
      SQL
    end
  end

  def down
    %w[
      better_together_webhook_endpoints
      better_together_webhook_deliveries
      better_together_inbound_email_messages
      better_together_reports
      better_together_content_security_findings
      better_together_content_security_items
      better_together_content_security_scan_events
      better_together_content_security_subjects
      better_together_contact_details
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
