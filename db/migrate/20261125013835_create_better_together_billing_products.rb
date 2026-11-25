# frozen_string_literal: true

# A one-off item a platform sells (a storage top-up, a one-time add-on, later tickets and other goods), and its prices.
# The product is the thing sold; a price is what a line item points at. `type` names a subclass from an allow-list, and
# `lifetime` says whether what a purchase gives ends when it is used up or after a term. Guarded so a re-run is a no-op.
class CreateBetterTogetherBillingProducts < ActiveRecord::Migration[7.2]
  def up
    create_products unless table_exists?(:better_together_billing_products)
    create_prices unless table_exists?(:better_together_billing_prices)
  end

  def down
    drop_table :better_together_billing_prices if table_exists?(:better_together_billing_prices)
    drop_table :better_together_billing_products if table_exists?(:better_together_billing_products)
  end

  private

  def create_products # rubocop:disable Metrics/MethodLength
    create_bt_table :billing_products do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_products_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :seller_type
      t.uuid :seller_id
      t.string :identifier, null: false
      t.string :type, null: false, default: 'BetterTogether::Billing::Product'
      t.boolean :active, null: false, default: true
      t.boolean :listed, null: false, default: false
      t.boolean :restricted_to_members, null: false, default: false
      t.boolean :restricted_to_subscribers, null: false, default: false
      t.uuid :tax_category_id
      t.string :lifetime, null: false, default: 'until_used'
      t.integer :term_length
      t.string :term_unit
      t.string :processor
      t.string :processor_product_id
      t.jsonb :metadata, null: false, default: {}
    end

    add_unique_identifier_indexes
    add_index :better_together_billing_products, :tax_category_id, name: 'idx_bt_billing_products_tax_category'
    add_index :better_together_billing_products, %i[id platform_id], unique: true, name: 'idx_bt_billing_products_id_platform'
  end

  def add_unique_identifier_indexes
    table = :better_together_billing_products
    add_index table, %i[platform_id identifier], unique: true, where: 'seller_id IS NULL',
                                                 name: 'idx_bt_billing_products_platform_identifier'
    add_index table, %i[platform_id seller_type seller_id identifier], unique: true, where: 'seller_id IS NOT NULL',
                                                                       name: 'idx_bt_billing_products_seller_identifier'
  end

  def create_prices
    create_bt_table :billing_prices do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_prices_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.references :product, null: false, type: :uuid, index: { name: 'idx_bt_billing_prices_product' },
                             foreign_key: { to_table: :better_together_billing_products }
      t.integer :amount_cents, null: false, default: 0
      t.string :currency, null: false
      t.boolean :active, null: false, default: true
      t.datetime :archived_at
      t.string :processor_price_id
    end

    add_index :better_together_billing_prices, %i[id platform_id], unique: true, name: 'idx_bt_billing_prices_id_platform'
  end
end
