# frozen_string_literal: true

# A plan is a kind of product (the `type` column), bought through its recurring prices, so the plans table goes. Each plan row
# becomes a product row and one recurring price row with the same id, which lets everything that pointed at the plan keep its id:
# order lines now name the price, subscription terms keep the plan and also name the price they were sold at, and entitlements and
# grants are keyed by product alone. Plan extras stay columns on the products table (grace and renewal lead days, payment methods).
# Guarded so a re-run, or a database that never had plans, is a no-op. See docs/billing/assessments/2026-11-billing-model-assessment.md.
class MergePlansIntoProducts < ActiveRecord::Migration[7.2]
  PLAN = 'BetterTogether::Billing::Plan'
  PRICE = 'BetterTogether::Billing::Price'
  PRODUCT = 'BetterTogether::Billing::Product'

  def up
    add_product_columns
    copy_plans if table_exists?(:better_together_billing_plans)
    rewire_terms
    rewire_item_keys(:better_together_billing_entitlements, 'entitlements')
    rewire_item_keys(:better_together_billing_plan_grants, 'plan_grants')
    drop_table :better_together_billing_plans, if_exists: true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def products = :better_together_billing_products

  def add_product_columns
    add_column products, :grace_days, :integer, default: 7, null: false unless column_exists?(products, :grace_days)
    add_column products, :renewal_lead_days, :integer, default: 14, null: false unless column_exists?(products, :renewal_lead_days)
    add_column products, :manages_processor_product, :boolean, default: true, null: false unless
      column_exists?(products, :manages_processor_product)
    add_column products, :accepted_payment_methods, :string, array: true, default: [], null: false unless
      column_exists?(products, :accepted_payment_methods)
    add_column products, :latest_processor_event_id, :string unless column_exists?(products, :latest_processor_event_id)
  end

  def copy_plans # rubocop:disable Metrics/MethodLength
    execute(<<~SQL.squish)
      INSERT INTO better_together_billing_products
        (id, lock_version, created_at, updated_at, platform_id, seller_type, seller_id, identifier, type, active, listed,
         restricted_to_members, restricted_to_subscribers, tax_category_id, processor, processor_product_id, metadata, sync_status,
         sync_error, sync_attempted_at, synced_to_processor_at, grace_days, renewal_lead_days, manages_processor_product,
         accepted_payment_methods, latest_processor_event_id)
      SELECT id, lock_version, created_at, updated_at, platform_id, seller_type, seller_id, identifier, '#{PLAN}', active, listed,
             restricted_to_members, restricted_to_subscribers, tax_category_id, processor, processor_product_id, metadata, sync_status,
             sync_error, sync_attempted_at, synced_to_processor_at, grace_days, renewal_lead_days, manages_processor_product,
             accepted_payment_methods, latest_processor_event_id
      FROM better_together_billing_plans
      ON CONFLICT (id) DO NOTHING
    SQL
    execute(<<~SQL.squish)
      INSERT INTO better_together_billing_prices
        (id, lock_version, created_at, updated_at, platform_id, product_id, amount_cents, currency, active, processor_price_id,
         kind, interval, interval_count)
      SELECT id, 0, created_at, updated_at, platform_id, id, amount_cents, currency, active, processor_price_id,
             'recurring', billing_interval, interval_count
      FROM better_together_billing_plans
      WHERE billing_interval IN ('month', 'year')
      ON CONFLICT (id) DO NOTHING
    SQL
    retype_references
  end

  def retype_references
    execute("UPDATE better_together_billing_line_items SET purchasable_type = '#{PRICE}' WHERE purchasable_type = '#{PLAN}'")
    execute("UPDATE better_together_billing_agreement_requirements SET target_type = '#{PRODUCT}' WHERE target_type = '#{PLAN}'")
    execute("UPDATE better_together_billing_purchase_requirements SET dependent_type = '#{PRODUCT}' WHERE dependent_type = '#{PLAN}'")
    execute("UPDATE better_together_billing_purchase_requirements SET prerequisite_type = '#{PRODUCT}' WHERE prerequisite_type = '#{PLAN}'")
    %w[mobility_string_translations mobility_text_translations].each do |table|
      execute("UPDATE #{table} SET translatable_type = '#{PRODUCT}' WHERE translatable_type = '#{PLAN}'") if table_exists?(table)
    end
  end

  def rewire_terms # rubocop:disable Metrics/MethodLength
    terms = :better_together_billing_subscription_terms
    return unless table_exists?(terms)

    add_column terms, :price_id, :uuid unless column_exists?(terms, :price_id)
    execute("UPDATE #{terms} SET price_id = plan_id WHERE price_id IS NULL")
    change_column_null terms, :price_id, false
    add_index terms, :price_id, name: 'idx_bt_billing_sub_terms_price' unless index_name_exists?(terms, 'idx_bt_billing_sub_terms_price')
    point_terms_at_products(terms)
    add_foreign_key terms, :better_together_billing_prices, column: %i[price_id platform_id], primary_key: %i[id platform_id],
                                                            name: 'fk_bt_billing_sub_terms_price_platform'
  end

  def point_terms_at_products(terms)
    remove_foreign_key terms, name: 'fk_bt_billing_sub_terms_plan_platform', if_exists: true
    remove_foreign_key terms, :better_together_billing_plans, column: :pending_plan_id, if_exists: true
    add_foreign_key terms, products, column: %i[plan_id platform_id], primary_key: %i[id platform_id],
                                     name: 'fk_bt_billing_sub_terms_plan_platform'
    add_foreign_key terms, products, column: :pending_plan_id, on_delete: :nullify
  end

  # Entitlements and grants named a plan or a product, exactly one; both are products now.
  def rewire_item_keys(table, label)
    return unless table_exists?(table) && column_exists?(table, :plan_id)

    execute("UPDATE #{table} SET product_id = plan_id WHERE plan_id IS NOT NULL AND product_id IS NULL")
    remove_check_constraints(table)
    remove_foreign_key table, name: "fk_bt_billing_#{label}_plan_platform", if_exists: true
    remove_index table, name: "idx_bt_billing_#{label}_plan", if_exists: true
    remove_index table, name: 'idx_bt_billing_entitlements_order_plan', if_exists: true
    remove_index table, name: 'idx_bt_billing_entitlements_one_live', if_exists: true
    remove_column table, :plan_id
    change_column_null table, :product_id, false
    add_live_subscription_index if label == 'entitlements'
  end

  def remove_check_constraints(table)
    %w[chk_bt_billing_entitlements_one_item chk_bt_billing_plan_grants_one_owner].each do |name|
      remove_check_constraint table, name:, if_exists: true
    end
  end

  # One live entitlement per holder and product for what a subscription gives.
  def add_live_subscription_index
    columns = %i[platform_id beneficiary_type beneficiary_id product_id]
    add_index :better_together_billing_entitlements, columns, unique: true, name: 'idx_bt_billing_entitlements_one_live',
                                                              where: "status IN ('active', 'grace') AND pay_subscription_id IS NOT NULL"
  end
end
