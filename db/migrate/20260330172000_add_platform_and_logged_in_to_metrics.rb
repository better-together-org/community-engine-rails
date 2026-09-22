# frozen_string_literal: true

class AddPlatformAndLoggedInToMetrics < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  class Platform < ActiveRecord::Base
    self.table_name = 'better_together_platforms'
  end

  RAW_METRIC_TABLES = %i[
    better_together_metrics_page_views
    better_together_metrics_link_clicks
    better_together_metrics_shares
    better_together_metrics_downloads
    better_together_metrics_search_queries
  ].freeze

  REPORT_TABLES = %i[
    better_together_metrics_page_view_reports
    better_together_metrics_link_click_reports
  ].freeze

  # Tables with a polymorphic content reference: derive platform_id from the
  # viewed/shared/downloaded record itself before falling back to host.
  CONTENT_REFERENCED_TABLES = {
    better_together_metrics_page_views: %w[pageable_type pageable_id],
    better_together_metrics_shares: %w[shareable_type shareable_id],
    better_together_metrics_downloads: %w[downloadable_type downloadable_id]
  }.freeze

  CONTENT_TYPES = {
    'BetterTogether::Post' => 'better_together_posts',
    'BetterTogether::Page' => 'better_together_pages',
    'BetterTogether::Event' => 'better_together_events'
  }.freeze

  def up
    RAW_METRIC_TABLES.each do |table|
      ensure_platform_reference!(table)
      ensure_logged_in!(table)
    end

    REPORT_TABLES.each do |table|
      ensure_platform_reference!(table)
    end

    backfill_platform_ids!

    (RAW_METRIC_TABLES + REPORT_TABLES).each do |table|
      change_column_null table, :platform_id, false if column_exists?(table, :platform_id)
    end
  end

  def down
    (RAW_METRIC_TABLES + REPORT_TABLES).reverse_each do |table|
      remove_foreign_key table, column: :platform_id if foreign_key_exists?(table, :better_together_platforms, column: :platform_id)
      remove_index table, :platform_id if index_exists?(table, :platform_id)
      remove_column table, :platform_id if column_exists?(table, :platform_id)
    end

    RAW_METRIC_TABLES.reverse_each do |table|
      remove_column table, :logged_in if column_exists?(table, :logged_in)
    end
  end

  private

  def ensure_platform_reference!(table)
    add_column table, :platform_id, :uuid unless column_exists?(table, :platform_id)
    add_index table, :platform_id unless index_exists?(table, :platform_id)
    return if foreign_key_exists?(table, :better_together_platforms, column: :platform_id)

    add_foreign_key table, :better_together_platforms, column: :platform_id
  end

  def ensure_logged_in!(table)
    return if column_exists?(table, :logged_in)

    add_column table, :logged_in, :boolean, default: false, null: false
  end

  def backfill_platform_ids!
    host_platform_id = Platform.where(host: true).pick(:id)

    if host_platform_id.blank?
      return unless metric_or_report_rows_exist?

      raise ActiveRecord::MigrationError, 'Cannot backfill metrics platform_id without a host platform'
    end

    CONTENT_REFERENCED_TABLES.each_key { |table| backfill_from_content_reference(table, host_platform_id) }
    # link_clicks and search_queries carry no content reference (URL strings only,
    # by design — metrics are anonymous and not tied to a resolvable record), so
    # they have no derivable owner and are correctly host-assigned directly.
    backfill_host_only(:better_together_metrics_link_clicks, host_platform_id)
    backfill_host_only(:better_together_metrics_search_queries, host_platform_id)
    REPORT_TABLES.each { |table| backfill_from_creator(table, host_platform_id) }
  end

  def backfill_from_content_reference(table, host_platform_id)
    type_col, id_col = CONTENT_REFERENCED_TABLES.fetch(table)

    CONTENT_TYPES.each do |type, owner_table|
      execute <<~SQL.squish
        UPDATE #{quote_table_name(table)} m
        SET platform_id = owner.platform_id
        FROM #{owner_table} owner
        WHERE m.#{type_col} = #{quote(type)}
          AND m.#{id_col} = owner.id
          AND m.platform_id IS NULL
          AND owner.platform_id IS NOT NULL
      SQL
    end

    backfill_host_only(table, host_platform_id)
  end

  def backfill_from_creator(table, host_platform_id)
    execute <<~SQL.squish
      UPDATE #{quote_table_name(table)} rec
      SET platform_id = ppm.joinable_id
      FROM better_together_people p
      JOIN better_together_person_platform_memberships ppm ON p.id = ppm.member_id
      WHERE rec.creator_id = p.id
        AND rec.platform_id IS NULL
        AND ppm.joinable_id IS NOT NULL
    SQL

    backfill_host_only(table, host_platform_id)
  end

  def backfill_host_only(table, host_platform_id)
    execute <<~SQL.squish
      UPDATE #{quote_table_name(table)}
      SET platform_id = #{quote(host_platform_id)}
      WHERE platform_id IS NULL
    SQL
  end

  def metric_or_report_rows_exist?
    (RAW_METRIC_TABLES + REPORT_TABLES).any? do |table|
      select_value("SELECT 1 FROM #{quote_table_name(table)} LIMIT 1").present?
    end
  end
end
