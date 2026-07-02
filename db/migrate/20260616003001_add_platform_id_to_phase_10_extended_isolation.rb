# frozen_string_literal: true

# Phase 10 — Extended isolation: Communication, Safety audit trails, PII
class AddPlatformIdToPhase10ExtendedIsolation < ActiveRecord::Migration[7.2]
  def change # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    # Communication infrastructure (3 tables)
    %w[
      better_together_webhook_endpoints
      better_together_webhook_deliveries
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Make inbound_email_messages.platform_id required (already exists as nullable)
    if column_exists?(:better_together_inbound_email_messages, :platform_id)
      change_column_null :better_together_inbound_email_messages, :platform_id, false
    else
      add_reference :better_together_inbound_email_messages, :platform,
                    type: :uuid, null: false,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # Safety & compliance audit trails (5 tables)
    %w[
      better_together_reports
      better_together_content_security_findings
      better_together_content_security_items
      better_together_content_security_scan_events
      better_together_content_security_subjects
    ].each do |table|
      next if column_exists?(table, :platform_id)

      add_reference table, :platform,
                    type: :uuid, null: true,
                    foreign_key: { to_table: :better_together_platforms },
                    index: true
    end

    # PII (personally identifiable information) — 6 tables
    # These are scoped polymorphically via contact_detail parent
    %w[
      better_together_contact_details
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
