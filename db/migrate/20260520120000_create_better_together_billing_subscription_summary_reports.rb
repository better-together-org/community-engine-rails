# frozen_string_literal: true

# Creates the table backing BetterTogether::Billing::Reports::SubscriptionSummaryReport.
# Mirrors the structure used by better_together_metrics_user_account_reports:
# JSONB filters + report_data, file_format string, creator FK, Active Storage attachment.
class CreateBetterTogetherBillingSubscriptionSummaryReports < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_subscription_summary_reports)

    create_bt_table :subscription_summary_reports, prefix: :better_together_billing do |t|
      t.jsonb  :filters,      null: false, default: {}
      t.string :file_format,  null: false, default: 'csv'
      t.jsonb  :report_data,  null: false, default: {}

      t.references :creator,
                   type: :uuid,
                   null: true,
                   foreign_key: { to_table: :better_together_people },
                   index: true
    end

    add_index :better_together_billing_subscription_summary_reports,
              :filters,
              using: :gin,
              name: 'idx_bt_billing_sub_summary_reports_filters'
  end
end
