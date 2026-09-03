# frozen_string_literal: true

# This migration is adapted from pay and guarded for partial-schema host upgrades.
class AddObjectToPayModels < ActiveRecord::Migration[7.2]
  def change
    add_column :pay_charges, :object, Pay::Adapter.json_column_type unless column_exists?(:pay_charges, :object)
    add_column :pay_customers, :object, Pay::Adapter.json_column_type unless column_exists?(:pay_customers, :object)
    add_column :pay_subscriptions, :object, Pay::Adapter.json_column_type unless column_exists?(:pay_subscriptions, :object)
  end
end
