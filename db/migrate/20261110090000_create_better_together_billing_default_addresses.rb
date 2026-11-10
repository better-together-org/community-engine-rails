# frozen_string_literal: true

# A person's default billing and shipping address for one platform, and the billing address an order was
# placed with. Guarded so a re-run is a no-op.
#
# * default_addresses is its own table (not Address#primary_flag), so "primary" stays general while a person
#   can have a default for billing and another for shipping.
# * An order keeps a SNAPSHOT of the billing address (billing_address, jsonb) as it read when the order was
#   placed, so editing or deleting the address later never changes the order. billing_address_id only says where it
#   came from and is cleared if the address is deleted.
class CreateBetterTogetherBillingDefaultAddresses < ActiveRecord::Migration[7.2]
  ORDERS = :better_together_billing_orders
  TABLE = :better_together_billing_default_addresses
  ORDER_ADDRESS_INDEX = 'idx_bt_billing_orders_billing_address'

  def up
    create_default_addresses
    add_order_columns
  end

  def down
    remove_foreign_key ORDERS, column: :billing_address_id if foreign_key_exists?(ORDERS, column: :billing_address_id)
    remove_index ORDERS, name: ORDER_ADDRESS_INDEX if index_name_exists?(ORDERS, ORDER_ADDRESS_INDEX)
    remove_column ORDERS, :billing_address_id if column_exists?(ORDERS, :billing_address_id)
    remove_column ORDERS, :billing_address if column_exists?(ORDERS, :billing_address)
    drop_table TABLE, force: :cascade if table_exists?(TABLE)
  end

  private

  def create_default_addresses
    return if table_exists?(TABLE)

    create_bt_table :billing_default_addresses do |t|
      t.uuid :platform_id, null: false
      t.uuid :person_id, null: false
      t.uuid :address_id, null: false
      t.string :kind, null: false
    end

    add_index TABLE, :platform_id, name: 'idx_bt_billing_default_addresses_platform'
    add_index TABLE, :address_id, name: 'idx_bt_billing_default_addresses_address'
    add_index TABLE, %i[platform_id person_id kind], unique: true, name: 'idx_bt_billing_default_addresses_person_kind'
    add_foreign_key TABLE, :better_together_platforms, column: :platform_id
    add_foreign_key TABLE, :better_together_people, column: :person_id, on_delete: :cascade
    add_foreign_key TABLE, :better_together_addresses, column: :address_id, on_delete: :cascade
  end

  def add_order_columns
    add_column ORDERS, :billing_address, :jsonb, null: false, default: {} unless column_exists?(ORDERS, :billing_address)
    add_column ORDERS, :billing_address_id, :uuid unless column_exists?(ORDERS, :billing_address_id)
    add_index ORDERS, :billing_address_id, name: ORDER_ADDRESS_INDEX unless index_name_exists?(ORDERS, ORDER_ADDRESS_INDEX)
    return if foreign_key_exists?(ORDERS, :better_together_addresses, column: :billing_address_id)

    add_foreign_key ORDERS, :better_together_addresses, column: :billing_address_id, on_delete: :nullify
  end
end
