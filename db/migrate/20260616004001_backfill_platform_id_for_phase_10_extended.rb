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

      enforce_inbound_email_platform_id_not_null!
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

    # Step 6: ContentSecurityItems from subject.
    # content_security_items has no direct subject_id FK — inherit from attachable objects
    # (Posts, Pages, Events) using the polymorphic attachable_type/attachable_id columns.
    if column_exists?(:better_together_content_security_items, :platform_id)
      [
        ["BetterTogether::Post",  "better_together_posts"],
        ["BetterTogether::Page",  "better_together_pages"],
        ["BetterTogether::Event", "better_together_events"]
      ].each do |type_name, parent_table|
        next unless table_exists?(parent_table) && column_exists?(parent_table, :platform_id)

        execute <<~SQL
          UPDATE better_together_content_security_items csi
          SET    platform_id = p.platform_id
          FROM   #{parent_table} p
          WHERE  csi.attachable_type = #{quote(type_name)}
            AND  csi.attachable_id   = p.id
            AND  csi.platform_id     IS NULL
            AND  p.platform_id       IS NOT NULL
        SQL
      end

      # Host platform fallback for items still without platform_id
      host_platform_id = execute(
        "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
      ).first&.fetch('id')

      if host_platform_id
        execute <<~SQL
          UPDATE better_together_content_security_items
          SET platform_id = #{quote(host_platform_id)}
          WHERE platform_id IS NULL
        SQL
      end
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

  private

  # 20260616003001 (which added this column) skips the NOT NULL constraint
  # rather than hard-failing if NULLs remain at that point in the sequence —
  # this is where it actually gets enforced, once this migration's own
  # backfill (including the host fallback above) has had a chance to run.
  def enforce_inbound_email_platform_id_not_null!
    return unless column_exists?(:better_together_inbound_email_messages, :platform_id)

    null_count = execute(
      'SELECT COUNT(*) FROM better_together_inbound_email_messages WHERE platform_id IS NULL'
    ).first['count'].to_i

    if null_count.positive?
      say "WARNING: #{null_count} row(s) in better_together_inbound_email_messages " \
          'still have NULL platform_id after backfill (no host platform found). ' \
          'Skipping NOT NULL constraint — re-run after completing platform setup.'
      return
    end

    change_column_null :better_together_inbound_email_messages, :platform_id, false
  end
end
