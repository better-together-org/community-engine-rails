# frozen_string_literal: true

# Adds bi-directional Stripe sync tracking columns to better_together_billing_plans:
#   - stripe_product_id: Stripe prod_xxx ID; populated on first outbound push
#   - sync_source: 'stripe_webhook' when inbound event is driving a save (loop guard)
#   - synced_to_stripe_at: timestamp of last successful outbound push
#   - latest_stripe_event_id: Stripe event ID that last mutated the plan via webhook
#
# Also adds a unique index on stripe_price_id to prevent ambiguous lookups in
# StripePriceSync and StripeSubscriptionSync.
class AddStripeSyncFieldsToBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans

  def change
    unless column_exists?(TABLE, :stripe_product_id)
      add_column TABLE, :stripe_product_id, :string, null: true
    end

    unless column_exists?(TABLE, :sync_source)
      add_column TABLE, :sync_source, :string, null: true
    end

    unless column_exists?(TABLE, :synced_to_stripe_at)
      add_column TABLE, :synced_to_stripe_at, :datetime, null: true
    end

    unless column_exists?(TABLE, :latest_stripe_event_id)
      add_column TABLE, :latest_stripe_event_id, :string, null: true
    end

    product_id_idx = 'idx_bt_billing_plans_stripe_product_id'
    return if index_name_exists?(TABLE, product_id_idx)

    add_index TABLE, :stripe_product_id,
              name: product_id_idx,
              unique: true,
              where: 'stripe_product_id IS NOT NULL'

    # stripe_price_id unique index already exists from the original billing tables
    # migration (name: idx_bt_billing_plans_stripe_price_id). No change needed.
  end
end
