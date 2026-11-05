# frozen_string_literal: true

# Final-state Pay tables (pay 11.x), uuid keys like every CE table. Guarded so it
# is safe on hosts that already ran Pay's own installer or a partial earlier run.
class CreateBetterTogetherPayTables < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up
    create_customers
    create_merchants
    create_payment_methods
    create_subscriptions
    create_charges
    create_webhooks
    ensure_sti_and_object_columns
    backfill_sti_types
  end

  def down
    %i[pay_webhooks pay_charges pay_subscriptions pay_payment_methods pay_merchants pay_customers].each do |table|
      drop_table table if table_exists?(table)
    end
  end

  private

  def json_type = Pay::Adapter.json_column_type

  def create_customers
    return if table_exists?(:pay_customers)

    create_table :pay_customers, id: :uuid do |t|
      t.belongs_to :owner, polymorphic: true, index: false, type: :uuid
      t.string :processor, null: false
      t.string :processor_id
      t.boolean :default
      t.public_send json_type, :data
      t.string :stripe_account
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :pay_customers, %i[owner_type owner_id deleted_at], name: :pay_customer_owner_index, unique: true
    add_index :pay_customers, %i[processor processor_id], unique: true
  end

  def create_merchants
    return if table_exists?(:pay_merchants)

    create_table :pay_merchants, id: :uuid do |t|
      t.belongs_to :owner, polymorphic: true, index: false, type: :uuid
      t.string :processor, null: false
      t.string :processor_id
      t.boolean :default
      t.public_send json_type, :data
      t.timestamps
    end
    add_index :pay_merchants, %i[owner_type owner_id processor]
  end

  def create_payment_methods
    return if table_exists?(:pay_payment_methods)

    create_table :pay_payment_methods, id: :uuid do |t|
      t.belongs_to :customer, foreign_key: { to_table: :pay_customers }, null: false, index: false, type: :uuid
      t.string :processor_id, null: false
      t.boolean :default
      t.string :payment_method_type
      t.public_send json_type, :data
      t.string :stripe_account
      t.timestamps
    end
    add_index :pay_payment_methods, %i[customer_id processor_id], unique: true
  end

  def create_subscriptions
    return if table_exists?(:pay_subscriptions)

    create_table :pay_subscriptions, id: :uuid do |t|
      t.belongs_to :customer, foreign_key: { to_table: :pay_customers }, null: false, index: false, type: :uuid
      t.string :name, null: false
      t.string :processor_id, null: false
      t.string :processor_plan, null: false
      t.integer :quantity, default: 1, null: false
      t.string :status, null: false
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_ends_at
      t.datetime :ends_at
      t.boolean :metered
      t.string :pause_behavior
      t.datetime :pause_starts_at
      t.datetime :pause_resumes_at
      t.decimal :application_fee_percent, precision: 8, scale: 2
      t.public_send json_type, :metadata
      t.public_send json_type, :data
      t.string :stripe_account
      t.string :payment_method_id
      t.timestamps
    end
    add_index :pay_subscriptions, %i[customer_id processor_id], unique: true
    add_index :pay_subscriptions, :metered
    add_index :pay_subscriptions, :pause_starts_at
  end

  def create_charges
    return if table_exists?(:pay_charges)

    create_table :pay_charges, id: :uuid do |t|
      t.belongs_to :customer, foreign_key: { to_table: :pay_customers }, null: false, index: false, type: :uuid
      t.belongs_to :subscription, foreign_key: { to_table: :pay_subscriptions }, null: true, type: :uuid
      t.string :processor_id, null: false
      t.integer :amount, null: false
      t.string :currency
      t.integer :application_fee_amount
      t.integer :amount_refunded
      t.public_send json_type, :metadata
      t.public_send json_type, :data
      t.string :stripe_account
      t.timestamps
    end
    add_index :pay_charges, %i[customer_id processor_id], unique: true
  end

  def create_webhooks
    return if table_exists?(:pay_webhooks)

    create_table :pay_webhooks, id: :uuid do |t|
      t.string :processor
      t.string :event_type
      t.public_send json_type, :event
      t.timestamps
    end
  end

  # Covers tables created by an older Pay install that predate these columns.
  def ensure_sti_and_object_columns
    %i[pay_customers pay_charges pay_subscriptions pay_payment_methods pay_merchants].each do |table|
      add_column table, :type, :string unless column_exists?(table, :type)
    end
    add_column :pay_payment_methods, :payment_method_type, :string unless column_exists?(:pay_payment_methods, :payment_method_type)
    %i[pay_charges pay_customers pay_subscriptions].each do |table|
      add_column table, :object, json_type unless column_exists?(table, :object)
    end
  end

  def backfill_sti_types
    backfill_type(:pay_customers, 'Customer')
    backfill_type(:pay_merchants, 'Merchant')
    { pay_charges: 'Charge', pay_subscriptions: 'Subscription', pay_payment_methods: 'PaymentMethod' }.each do |table, kind|
      backfill_type(table, kind, via_customer: true)
    end
  end

  def backfill_type(table, kind, via_customer: false)
    source = via_customer ? :pay_customers : table
    select_values("SELECT DISTINCT processor FROM #{source} WHERE processor IS NOT NULL").each do |processor|
      type_name = "Pay::#{processor.classify}::#{kind}"
      match = "processor = #{quote(processor)}"
      where = via_customer ? "customer_id IN (SELECT id FROM pay_customers WHERE #{match})" : match
      execute("UPDATE #{table} SET type = #{quote(type_name)} WHERE type IS NULL AND #{where}")
    end
  end
end
