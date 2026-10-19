# frozen_string_literal: true

# This migration is adapted from pay and guarded for partial-schema host upgrades.
class AddPayStiColumns < ActiveRecord::Migration[7.2]
  def up
    add_sti_columns
    normalize_payment_method_type_column
    backfill_pay_sti_types
  end

  def down
    remove_sti_columns
    restore_payment_method_type_column
  end

  private

  def add_sti_columns
    add_column_unless_exists :pay_customers, :type, :string
    add_column_unless_exists :pay_charges, :type, :string
    add_column_unless_exists :pay_subscriptions, :type, :string
    add_column_unless_exists :pay_payment_methods, :type, :string
    add_column_unless_exists :pay_merchants, :type, :string
  end

  def remove_sti_columns
    remove_column_if_exists :pay_merchants, :type
    remove_column_if_exists :pay_payment_methods, :type
    remove_column_if_exists :pay_subscriptions, :type
    remove_column_if_exists :pay_charges, :type
    remove_column_if_exists :pay_customers, :type
  end

  def normalize_payment_method_type_column
    return unless column_exists?(:pay_payment_methods, :type)
    return if column_exists?(:pay_payment_methods, :payment_method_type)

    rename_column :pay_payment_methods, :type, :payment_method_type
    add_column :pay_payment_methods, :type, :string unless column_exists?(:pay_payment_methods, :type)
  end

  def restore_payment_method_type_column
    return unless column_exists?(:pay_payment_methods, :payment_method_type)
    return if column_exists?(:pay_payment_methods, :type)

    rename_column :pay_payment_methods, :payment_method_type, :type
  end

  def backfill_pay_sti_types
    return unless defined?(Pay::Customer) && Pay::Customer.table_exists?

    Pay::Customer.find_each do |pay_customer|
      backfill_customer_types(pay_customer)
    end

    Pay::Merchant.find_each do |pay_merchant|
      pay_merchant.update(type: "Pay::#{pay_merchant.processor.classify}::Merchant") if pay_merchant.respond_to?(:type)
    end
  end

  def backfill_customer_types(pay_customer)
    processor_name = pay_customer.processor.classify

    pay_customer.update(type: "Pay::#{processor_name}::Customer") if pay_customer.respond_to?(:type)
    update_relation_type(pay_customer.charges, "Pay::#{processor_name}::Charge")
    update_relation_type(pay_customer.subscriptions, "Pay::#{processor_name}::Subscription")
    update_relation_type(pay_customer.payment_methods, "Pay::#{processor_name}::PaymentMethod")
  end

  def update_relation_type(relation, type_name)
    return unless relation.klass.column_names.include?('type')

    relation.update_all(type: type_name)
  end

  def add_column_unless_exists(table_name, column_name, type)
    return if column_exists?(table_name, column_name)

    add_column table_name, column_name, type
  end

  def remove_column_if_exists(table_name, column_name)
    return unless column_exists?(table_name, column_name)

    remove_column table_name, column_name
  end
end
