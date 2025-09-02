class CreateBetterTogetherMetricsLinkCheckerReports < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :metrics_link_checker_reports do |t|
      t.jsonb :filters, default: {}, null: false
      t.string :file_format, default: 'csv', null: false
      t.jsonb :report_data, default: {}, null: false
    end

    add_index :better_together_metrics_link_checker_reports, :filters, using: :gin, name: 'index_better_together_metrics_link_checker_reports_on_filters' # rubocop:disable Layout/LineLength
  end
end
