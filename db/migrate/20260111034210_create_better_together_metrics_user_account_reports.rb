# frozen_string_literal: true

# Creates a db table to track and retrieve the UserAccountReport data
class CreateBetterTogetherMetricsUserAccountReports < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :user_account_reports, prefix: :better_together_metrics do |t|
      t.jsonb   :filters,         null: false, default: {}
      t.string  :file_format,     null: false, default: "csv"
      t.jsonb   :report_data,     null: false, default: {}
    end

    add_index :better_together_metrics_user_account_reports, :filters, using: :gin
  end
end
