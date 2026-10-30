# frozen_string_literal: true

# Processor-neutral plan catalog. A plan is one price at one payment processor
# (processor + processor_price_id). Final state; guarded so a re-run is a no-op.
#
# * platform_id NOT NULL: a plan belongs to exactly one platform, and its identifier is
#   unique within that platform (not globally), so platforms can use the same names.
# * processor_price_id is NULL until the processor-side price exists: a steward can
#   create a plan in Community Engine and the sync job creates the product and price, or
#   link a price that already exists. It is unique per processor, so one tenant cannot
#   claim another's price.
# * processor_product_id is NOT unique: a processor product commonly has several prices
#   (monthly and yearly). Which platform may use a product is checked by the model.
# * sync_status / sync_error / sync_attempted_at show a steward where a push stands. The
#   error is a short code, never raw processor text.
# * No currency default: the host or the steward chooses.
class CreateBetterTogetherBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_plans do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_plans_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :identifier, null: false
      t.string :name, null: false
      t.text :description
      t.string :billing_interval, null: false, default: 'month'
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false
      t.boolean :active, null: false, default: true
      t.string :processor, null: false
      t.string :processor_price_id
      t.string :processor_product_id
      t.boolean :manages_processor_product, null: false, default: true
      t.string :sync_status, null: false, default: 'pending'
      t.string :sync_error
      t.datetime :sync_attempted_at
      t.datetime :synced_to_processor_at
      t.string :latest_processor_event_id
      t.jsonb :metadata, null: false, default: {}
    end

    add_indexes
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def add_indexes
    add_index TABLE, %i[platform_id identifier], unique: true, name: 'idx_bt_billing_plans_platform_identifier'
    add_index TABLE, :active, name: 'idx_bt_billing_plans_active'
    add_index TABLE, :sync_status, name: 'idx_bt_billing_plans_sync_status'
    add_index TABLE, %i[processor processor_price_id], unique: true, name: 'idx_bt_billing_plans_processor_price'
    add_index TABLE, %i[processor processor_product_id], name: 'idx_bt_billing_plans_processor_product'
  end
end
