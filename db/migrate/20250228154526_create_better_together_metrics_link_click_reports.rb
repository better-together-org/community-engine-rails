class CreateBetterTogetherMetricsLinkClickReports < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :link_click_reports, prefix: :better_together_metrics do |t|
      t.jsonb   :filters,                null: false, default: {}
      t.boolean :sort_by_total_clicks,   null: false, default: false
      t.string  :file_format,            null: false, default: "csv"
      t.jsonb   :report_data,            null: false, default: {}
    end

    add_index :better_together_metrics_link_click_reports, :filters, using: :gin
  end
end
