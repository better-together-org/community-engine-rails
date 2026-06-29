# frozen_string_literal: true

# Replaces the old standalone billing_subscriptions table (which duplicated pay's
# status/processor columns and had polymorphic owner/beneficiary) with a thin
# CE extension record that hangs CE-specific data off pay's Pay::Subscription.
#
# After this migration:
#   - pay_subscription_id (uuid, NOT NULL, UNIQUE) FK → pay_subscriptions
#   - billing_plan_id kept (FK → better_together_billing_plans)
#   - sync_source, latest_checkout_session_id, latest_processor_event_id,
#     last_synced_at, metadata kept
#   - All duplicated pay columns and polymorphic owner/beneficiary columns removed
class ReplaceBillingSubscriptionsWithPayExtension < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  TABLE = :better_together_billing_subscriptions
  PAY_SUBSCRIPTION_INDEX = 'idx_bt_billing_subscriptions_pay_subscription'

  def up
    return unless table_exists?(TABLE)

    ensure_pay_subscription_id_column
    backfill_pay_subscription_id!
    ensure_pay_subscription_id_index
    ensure_pay_subscription_foreign_key
    enforce_pay_subscription_not_null!

    # ── Remove old indexes ───────────────────────────────────────────────────
    remove_index TABLE, name: 'idx_bt_billing_subscriptions_community' if index_name_exists?(TABLE,
                                                                                             'idx_bt_billing_subscriptions_community')
    community_status_idx = 'idx_bt_billing_subscriptions_community_status'
    remove_index TABLE, name: community_status_idx if index_name_exists?(TABLE, community_status_idx)
    remove_index TABLE, name: 'idx_bt_billing_subscriptions_processor_id'    if index_name_exists?(TABLE,
                                                                                                   'idx_bt_billing_subscriptions_processor_id')
    remove_index TABLE, name: 'idx_bt_billing_subscriptions_status'          if index_name_exists?(TABLE, 'idx_bt_billing_subscriptions_status')
    remove_index TABLE, name: 'idx_bt_billing_subscriptions_owner'           if index_name_exists?(TABLE, 'idx_bt_billing_subscriptions_owner')
    remove_index TABLE, name: 'idx_bt_billing_subscriptions_beneficiary'     if index_name_exists?(TABLE,
                                                                                                   'idx_bt_billing_subscriptions_beneficiary')

    # ── Remove old foreign keys ──────────────────────────────────────────────
    if foreign_key_exists?(TABLE, column: :community_id)
      remove_foreign_key TABLE, column: :community_id
    end

    # ── Drop old columns ─────────────────────────────────────────────────────
    %i[
      community_id
      processor
      processor_subscription_id
      pay_customer_id
      status
      current_period_start
      current_period_end
      cancel_at_period_end
      billable_owner_type
      billable_owner_id
      beneficiary_type
      beneficiary_id
    ].each do |col|
      remove_column TABLE, col if column_exists?(TABLE, col)
    end
  end

  def down
    return unless table_exists?(TABLE)

    # Remove new FK and column
    if foreign_key_exists?(TABLE, column: :pay_subscription_id)
      remove_foreign_key TABLE, column: :pay_subscription_id
    end
    remove_index TABLE, name: PAY_SUBSCRIPTION_INDEX if index_name_exists?(TABLE, PAY_SUBSCRIPTION_INDEX)
    remove_column TABLE, :pay_subscription_id if column_exists?(TABLE, :pay_subscription_id)

    # Restore old columns (nullability relaxed for reversibility)
    add_column TABLE, :community_id,               :uuid
    add_column TABLE, :processor,                  :string,  null: false, default: 'stripe'
    add_column TABLE, :processor_subscription_id,  :string,  null: false, default: ''
    add_column TABLE, :pay_customer_id,             :string
    add_column TABLE, :status,                      :string, null: false, default: 'incomplete'
    add_column TABLE, :current_period_start,        :datetime
    add_column TABLE, :current_period_end,          :datetime
    add_column TABLE, :cancel_at_period_end,        :boolean, null: false, default: false
    add_column TABLE, :billable_owner_type,         :string
    add_column TABLE, :billable_owner_id,           :uuid
    add_column TABLE, :beneficiary_type,            :string
    add_column TABLE, :beneficiary_id,              :uuid

    add_index TABLE, :community_id,                                 name: 'idx_bt_billing_subscriptions_community'
    add_index TABLE, %i[community_id status],                       name: 'idx_bt_billing_subscriptions_community_status'
    add_index TABLE, :processor_subscription_id, unique: true,      name: 'idx_bt_billing_subscriptions_processor_id'
    add_index TABLE, :status,                                       name: 'idx_bt_billing_subscriptions_status'
    add_index TABLE, %i[billable_owner_type billable_owner_id],     name: 'idx_bt_billing_subscriptions_owner'
    add_index TABLE, %i[beneficiary_type beneficiary_id],           name: 'idx_bt_billing_subscriptions_beneficiary'

    add_foreign_key TABLE, :better_together_communities, column: :community_id, on_delete: :cascade
  end

  private

  def ensure_pay_subscription_id_column
    return if column_exists?(TABLE, :pay_subscription_id)

    add_column TABLE, :pay_subscription_id, :uuid
  end

  def backfill_pay_subscription_id!
    return unless column_exists?(TABLE, :pay_subscription_id)
    return unless column_exists?(TABLE, :processor_subscription_id)

    execute <<~SQL.squish
      UPDATE #{quote_table_name(TABLE)} AS billing_subscriptions
      SET pay_subscription_id = pay_subscriptions.id
      FROM #{quote_table_name(:pay_subscriptions)} AS pay_subscriptions
      INNER JOIN #{quote_table_name(:pay_customers)} AS pay_customers
        ON pay_customers.id = pay_subscriptions.customer_id
      WHERE billing_subscriptions.pay_subscription_id IS NULL
        AND billing_subscriptions.processor_subscription_id = pay_subscriptions.processor_id
        AND (
          billing_subscriptions.pay_customer_id IS NULL OR
          billing_subscriptions.pay_customer_id = pay_customers.processor_id
        )
    SQL
  end

  def ensure_pay_subscription_id_index
    return if index_name_exists?(TABLE, PAY_SUBSCRIPTION_INDEX)

    add_index TABLE, :pay_subscription_id, unique: true, name: PAY_SUBSCRIPTION_INDEX
  end

  def ensure_pay_subscription_foreign_key
    return if foreign_key_exists?(TABLE, :pay_subscriptions, column: :pay_subscription_id)

    add_foreign_key TABLE, :pay_subscriptions, column: :pay_subscription_id, on_delete: :cascade
  end

  def enforce_pay_subscription_not_null!
    return unless column_exists?(TABLE, :pay_subscription_id)
    return if connection.select_value(<<~SQL.squish).present?
      SELECT 1
      FROM #{quote_table_name(TABLE)}
      WHERE pay_subscription_id IS NULL
      LIMIT 1
    SQL

    change_column_null TABLE, :pay_subscription_id, false
  end
end
