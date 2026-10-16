# frozen_string_literal: true

# Processor-neutral plan catalog. A plan links to one price at one payment
# processor (processor + processor_price_id); no currency or country default.
class CreateBetterTogetherBillingPlans < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_plans

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_plans do |t|
      t.string :identifier, null: false
      t.string :name, null: false
      t.text :description
      t.string :billing_interval, null: false, default: 'month'
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false
      t.boolean :active, null: false, default: true
      t.string :processor, null: false
      t.string :processor_price_id, null: false
      t.string :processor_product_id
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
    add_index TABLE, :identifier, unique: true, name: 'idx_bt_billing_plans_identifier'
    add_index TABLE, :active, name: 'idx_bt_billing_plans_active'
    add_index TABLE, %i[processor processor_price_id], unique: true, name: 'idx_bt_billing_plans_processor_price'
    add_index TABLE, %i[processor processor_product_id], unique: true, where: 'processor_product_id IS NOT NULL',
                                                         name: 'idx_bt_billing_plans_processor_product'
  end
end
