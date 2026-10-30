# frozen_string_literal: true

# Pay's tables in their final shape (pay 11.x), owned by Community Engine:
#
# * uuid keys, like every CE table;
# * every table except pay_webhooks is bound to a platform (platform_id NOT NULL),
#   and children are tied to their customer's platform by composite foreign keys,
#   so a charge, subscription or payment method can never belong to a different
#   platform than its customer (see BetterTogether::Billing::PayExtensions::PlatformScoping);
# * Pay's JSON columns are plain text because the models encrypt them
#   (BetterTogether::Billing::PayExtensions::EncryptedBillingData). Encrypted values
#   are not valid JSON documents, so jsonb/json columns cannot hold them;
# * pay_webhooks rows are transient (Pay deletes a row once it is processed), so
#   they carry no platform; the encrypted event is pruned if processing fails.
#
# Guarded so a retried run is a no-op. Nothing here reconciles older Pay
# installs: no billing data exists to migrate.
class CreateBetterTogetherPayTables < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  PLATFORMS_TABLE = :better_together_platforms

  def up
    create_customers
    create_merchants
    create_payment_methods
    create_subscriptions
    create_charges
    create_webhooks
    add_platform_integrity_keys
  end

  # Children first, so foreign keys never block a drop.
  def down
    %i[pay_webhooks pay_charges pay_payment_methods pay_subscriptions pay_merchants pay_customers].each do |table|
      drop_table table, if_exists: true
    end
  end

  private

  def platform_reference(table)
    table.references :platform, null: false, type: :uuid, index: true,
                                foreign_key: { to_table: PLATFORMS_TABLE }
  end

  def create_customers
    return if table_exists?(:pay_customers)

    create_table :pay_customers, id: :uuid do |t|
      platform_reference(t)
      t.belongs_to :owner, polymorphic: true, index: false, type: :uuid
      t.string :processor, null: false
      t.string :processor_id
      t.boolean :default
      t.text :data
      t.text :object
      t.string :stripe_account
      t.datetime :deleted_at
      t.string :type
      t.timestamps
    end
    add_index :pay_customers, %i[platform_id owner_type owner_id deleted_at], unique: true, name: :pay_customer_owner_index
    add_index :pay_customers, %i[platform_id processor processor_id], unique: true, name: :pay_customers_platform_processor_index
    add_index :pay_customers, %i[id platform_id], unique: true, name: :pay_customers_id_platform_index
  end

  def create_merchants
    return if table_exists?(:pay_merchants)

    create_table :pay_merchants, id: :uuid do |t|
      platform_reference(t)
      t.belongs_to :owner, polymorphic: true, index: false, type: :uuid
      t.string :processor, null: false
      t.string :processor_id
      t.boolean :default
      t.text :data
      t.string :type
      t.timestamps
    end
    add_index :pay_merchants, %i[platform_id owner_type owner_id processor], name: :pay_merchants_platform_owner_index
  end

  def create_payment_methods
    return if table_exists?(:pay_payment_methods)

    create_table :pay_payment_methods, id: :uuid do |t|
      platform_reference(t)
      t.uuid :customer_id, null: false
      t.string :processor_id, null: false
      t.boolean :default
      t.string :payment_method_type
      t.text :data
      t.string :stripe_account
      t.string :type
      t.timestamps
    end
    add_index :pay_payment_methods, %i[customer_id processor_id], unique: true
  end

  def create_subscriptions
    return if table_exists?(:pay_subscriptions)

    create_table :pay_subscriptions, id: :uuid do |t|
      platform_reference(t)
      t.uuid :customer_id, null: false
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
      t.text :metadata
      t.text :data
      t.text :object
      t.string :stripe_account
      t.string :payment_method_id
      t.string :type
      t.timestamps
    end
    add_index :pay_subscriptions, %i[customer_id processor_id], unique: true
    add_index :pay_subscriptions, :metered
    add_index :pay_subscriptions, :pause_starts_at
    add_index :pay_subscriptions, %i[id platform_id], unique: true, name: :pay_subscriptions_id_platform_index
  end

  def create_charges
    return if table_exists?(:pay_charges)

    create_table :pay_charges, id: :uuid do |t|
      platform_reference(t)
      t.uuid :customer_id, null: false
      t.uuid :subscription_id, index: true
      t.string :processor_id, null: false
      t.integer :amount, null: false
      t.string :currency
      t.integer :application_fee_amount
      t.integer :amount_refunded
      t.text :metadata
      t.text :data
      t.text :object
      t.string :stripe_account
      t.string :type
      t.timestamps
    end
    add_index :pay_charges, %i[customer_id processor_id], unique: true
  end

  def create_webhooks
    return if table_exists?(:pay_webhooks)

    create_table :pay_webhooks, id: :uuid do |t|
      t.string :processor
      t.string :event_type
      t.text :event
      t.timestamps
    end
  end

  # Composite keys make the database refuse a child row whose platform differs
  # from its customer's (or its subscription's). A NULL subscription_id on a charge
  # is not checked (MATCH SIMPLE), which is what a one-off charge needs.
  def add_platform_integrity_keys
    {
      pay_payment_methods: [%i[pay_customers customer_id]],
      pay_subscriptions: [%i[pay_customers customer_id]],
      pay_charges: [%i[pay_customers customer_id], %i[pay_subscriptions subscription_id]]
    }.each do |table, parents|
      parents.each do |parent, column|
        name = "fk_#{table}_#{column}_platform"
        next if foreign_key_exists?(table, name:)

        add_foreign_key table, parent, column: [column, :platform_id], primary_key: %i[id platform_id], name:
      end
    end
  end
end
