# frozen_string_literal: true

# A saved billing report (sales, revenue, tax and refunds for a span), kept like the other metrics reports: the
# filters it was asked with, the figures as they were when it was made, and a CSV file attached once generated.
class CreateBetterTogetherMetricsBillingReports < ActiveRecord::Migration[7.2]
  TABLE = :better_together_metrics_billing_reports

  def up
    create_report_table
    add_report_index :platform_id, 'idx_bt_metrics_billing_reports_platform'
    add_report_index :creator_id, 'idx_bt_metrics_billing_reports_creator'
    add_foreign_keys
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def create_report_table
    return if table_exists?(TABLE)

    create_bt_table :billing_reports, prefix: :better_together_metrics do |t|
      t.uuid   :platform_id, null: false
      t.uuid   :creator_id
      t.jsonb  :filters,     null: false, default: {}
      t.string :file_format, null: false, default: 'csv'
      t.jsonb  :report_data, null: false, default: {}
    end
  end

  def add_report_index(column, name)
    add_index TABLE, column, name: name unless index_name_exists?(TABLE, name)
  end

  def add_foreign_keys
    unless foreign_key_exists?(TABLE, :better_together_platforms, column: :platform_id)
      add_foreign_key TABLE, :better_together_platforms, column: :platform_id
    end
    return if foreign_key_exists?(TABLE, :better_together_people, column: :creator_id)

    add_foreign_key TABLE, :better_together_people, column: :creator_id
  end
end
