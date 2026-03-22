# frozen_string_literal: true

# Migration to create the better_together_metrics_link_checker_reports table.
#
# This migration defines the following columns:
# - filters: JSONB column to store filter criteria, defaults to an empty object, cannot be null.
# - file_format: String column to specify the format of the report file, defaults to 'csv', cannot be null.
# - report_data: JSONB column to store the report data, defaults to an empty object, cannot be null.
#
# Additionally, it adds a GIN index on the filters column to optimize queries involving JSONB data.
# Migration to create the metrics link checker reports table used by the LinkCheckerReport model
class CreateBetterTogetherMetricsLinkCheckerReports < ActiveRecord::Migration[7.1]
  def change
    return if table_exists? :better_together_metrics_link_checker_reports

    create_bt_table :metrics_link_checker_reports do |t|
      t.jsonb :filters, default: {}, null: false
      t.string :file_format, default: 'csv', null: false
      t.jsonb :report_data, default: {}, null: false
    end

    add_index :better_together_metrics_link_checker_reports, :filters, using: :gin, name: 'index_better_together_metrics_link_checker_reports_on_filters' # rubocop:disable Layout/LineLength
  end
end
