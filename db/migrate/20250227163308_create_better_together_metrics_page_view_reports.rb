# frozen_string_literal: true

# Creates a db table to track and retrieve the PageViewReport data
class CreateBetterTogetherMetricsPageViewReports < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :page_view_reports, prefix: :better_together_metrics do |t|
      t.jsonb   :filters,             null: false, default: {}
      t.boolean :sort_by_total_views, null: false, default: false
      t.string  :file_format,         null: false, default: 'csv'
      t.jsonb   :report_data,         null: false, default: {}
    end

    add_index :better_together_metrics_page_view_reports, :filters, using: :gin
  end
end
