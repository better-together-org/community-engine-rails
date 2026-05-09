# frozen_string_literal: true

class AddPayloadRedactionTrackingToBillingEvents < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_billing_events)

    unless column_exists?(:better_together_billing_events, :payload_redacted_at)
      add_column :better_together_billing_events, :payload_redacted_at, :datetime
    end

    unless index_exists?(:better_together_billing_events, :payload_redacted_at,
                         name: 'idx_bt_billing_events_payload_redacted_at')
      add_index :better_together_billing_events, :payload_redacted_at,
                name: 'idx_bt_billing_events_payload_redacted_at'
    end
  end
end
