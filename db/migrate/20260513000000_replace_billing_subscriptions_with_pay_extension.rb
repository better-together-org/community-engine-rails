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
class ReplaceBillingSubscriptionsWithPayExtension < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_subscriptions

  def up
    return unless table_exists?(TABLE)

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

    # ── Add pay_subscription_id ──────────────────────────────────────────────
    return if column_exists?(TABLE, :pay_subscription_id)

    add_column TABLE, :pay_subscription_id, :uuid, null: false

    add_index TABLE, :pay_subscription_id,
              unique: true,
              name: 'idx_bt_billing_subscriptions_pay_subscription'

    add_foreign_key TABLE, :pay_subscriptions,
                    column: :pay_subscription_id,
                    on_delete: :cascade
  end

  def down
    return unless table_exists?(TABLE)

    # Remove new FK and column
    if foreign_key_exists?(TABLE, column: :pay_subscription_id)
      remove_foreign_key TABLE, column: :pay_subscription_id
    end
    pay_sub_idx = 'idx_bt_billing_subscriptions_pay_subscription'
    remove_index TABLE, name: pay_sub_idx if index_name_exists?(TABLE, pay_sub_idx)
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
end
