# frozen_string_literal: true

class AddPlatformAndLoggedInToMetrics < ActiveRecord::Migration[7.2]
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

    (RAW_METRIC_TABLES + REPORT_TABLES).each do |table|
      execute <<~SQL.squish
        UPDATE #{quote_table_name(table)}
        SET platform_id = #{quote(host_platform_id)}
        WHERE platform_id IS NULL
      SQL
    end
  end

  def metric_or_report_rows_exist?
    (RAW_METRIC_TABLES + REPORT_TABLES).any? do |table|
      select_value("SELECT 1 FROM #{quote_table_name(table)} LIMIT 1").present?
    end
  end
end
