# frozen_string_literal: true

# Tax: who collects it (registrations), what is taxed (categories), where and at what rate (zones, rates),
# and what was charged on an order (tax lines). Guarded so a re-run is a no-op.
#
# * Every table carries platform_id NOT NULL; children are tied to their parent's platform by a COMPOSITE
#   foreign key, as the other billing tables are.
# * A tax line copies the label and rate when the order was placed, so changing a rate later never
#   changes an order that already exists.
# * An order with no tax registration behind it has no tax lines and the totals it always had.
# * Money is integer minor units plus the order's currency. Rates are fractions (0.05 is five percent).
# * registration_number is `text` because the model encrypts it.
class CreateBetterTogetherBillingTax < ActiveRecord::Migration[7.2] # rubocop:disable Metrics/ClassLength
  def up
    create_tax_categories
    create_tax_zones
    create_tax_rates
    create_tax_registrations
    create_tax_lines
    add_tax_columns
  end

  def down
    remove_tax_columns
    %i[better_together_billing_tax_lines better_together_billing_tax_registrations better_together_billing_tax_rates
       better_together_billing_tax_zones better_together_billing_tax_categories].each do |table|
      drop_table table, force: :cascade if table_exists?(table)
    end
  end

  private

  def create_tax_categories
    return if table_exists?(:better_together_billing_tax_categories)

    create_bt_table :billing_tax_categories do |t|
      t.uuid :platform_id, null: false
      t.string :identifier, null: false
      t.string :name, null: false
      # false: nothing in this category is taxed (fresh produce, say), whatever the rates are.
      t.boolean :taxable, null: false, default: true
    end

    add_index :better_together_billing_tax_categories, :platform_id, name: 'idx_bt_billing_tax_categories_platform'
    add_index :better_together_billing_tax_categories, %i[id platform_id], unique: true, name: 'idx_bt_billing_tax_categories_id_platform'
    add_index :better_together_billing_tax_categories, %i[platform_id identifier], unique: true,
                                                                                   name: 'idx_bt_billing_tax_categories_identifier'
    add_foreign_key :better_together_billing_tax_categories, :better_together_platforms, column: :platform_id
  end

  def create_tax_zones
    return if table_exists?(:better_together_billing_tax_zones)

    create_bt_table :billing_tax_zones do |t|
      t.uuid :platform_id, null: false
      t.string :name, null: false
      # The place is a row of the geography tables, never a string: a country, one state or province of it, or one
      # settlement (a city or town) in it, which is how a municipal tax is held. Tax at each level adds to the
      # levels above it.
      t.uuid :country_id, null: false
      t.uuid :state_id
      t.uuid :settlement_id
    end

    add_index :better_together_billing_tax_zones, :platform_id, name: 'idx_bt_billing_tax_zones_platform'
    add_index :better_together_billing_tax_zones, %i[id platform_id], unique: true, name: 'idx_bt_billing_tax_zones_id_platform'
    add_index :better_together_billing_tax_zones, %i[platform_id country_id state_id settlement_id], name: 'idx_bt_billing_tax_zones_place'
    add_index :better_together_billing_tax_zones, :settlement_id, name: 'idx_bt_billing_tax_zones_settlement'
    add_foreign_key :better_together_billing_tax_zones, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_tax_zones, :better_together_geography_countries, column: :country_id
    add_foreign_key :better_together_billing_tax_zones, :better_together_geography_states, column: :state_id
    add_foreign_key :better_together_billing_tax_zones, :better_together_geography_settlements, column: :settlement_id
  end

  def create_tax_rates # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_tax_rates)

    create_bt_table :billing_tax_rates do |t|
      t.uuid :platform_id, null: false
      t.uuid :tax_zone_id, null: false
      # Empty: every taxable category.
      t.uuid :tax_category_id
      t.string :label, null: false
      t.decimal :rate, precision: 8, scale: 5, null: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.datetime :discarded_at
    end

    add_index :better_together_billing_tax_rates, :platform_id, name: 'idx_bt_billing_tax_rates_platform'
    add_index :better_together_billing_tax_rates, :tax_zone_id, name: 'idx_bt_billing_tax_rates_zone'
    add_index :better_together_billing_tax_rates, %i[id platform_id], unique: true, name: 'idx_bt_billing_tax_rates_id_platform'
    add_foreign_key :better_together_billing_tax_rates, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_tax_rates, :better_together_billing_tax_zones,
                    column: %i[tax_zone_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_tax_rates_zone_platform'
    add_foreign_key :better_together_billing_tax_rates, :better_together_billing_tax_categories,
                    column: %i[tax_category_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_tax_rates_category_platform'
  end

  def create_tax_registrations # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_tax_registrations)

    create_bt_table :billing_tax_registrations do |t|
      t.uuid :platform_id, null: false
      # Empty: the platform itself is the registrant; otherwise a community or person on it.
      t.string :seller_type
      t.uuid :seller_id
      t.string :country_iso, null: false
      t.string :region_code
      t.string :status, null: false, default: 'registered'
      # Empty: the default for the country (see Billing::Tax::Defaults).
      t.boolean :prices_include_tax
      t.text :registration_number
      t.datetime :effective_from
      t.datetime :effective_to
    end

    add_index :better_together_billing_tax_registrations, :platform_id, name: 'idx_bt_billing_tax_registrations_platform'
    add_index :better_together_billing_tax_registrations, %i[id platform_id], unique: true,
                                                                              name: 'idx_bt_billing_tax_registrations_id_platform'
    add_index :better_together_billing_tax_registrations, %i[seller_type seller_id], name: 'idx_bt_billing_tax_registrations_seller'
    add_foreign_key :better_together_billing_tax_registrations, :better_together_platforms, column: :platform_id
  end

  def create_tax_lines # rubocop:disable Metrics/MethodLength
    return if table_exists?(:better_together_billing_tax_lines)

    create_bt_table :billing_tax_lines do |t|
      t.uuid :platform_id, null: false
      t.uuid :order_id, null: false
      t.uuid :line_item_id, null: false
      t.uuid :tax_rate_id
      t.string :label, null: false
      t.decimal :rate, precision: 8, scale: 5, null: false
      t.integer :amount_cents, null: false
      t.boolean :included, null: false, default: false
    end

    # A tax line is tied to its line item's platform too, which needs the pair to be unique there.
    unless index_name_exists?(:better_together_billing_line_items, 'idx_bt_billing_line_items_id_platform')
      add_index :better_together_billing_line_items, %i[id platform_id], unique: true, name: 'idx_bt_billing_line_items_id_platform'
    end

    add_index :better_together_billing_tax_lines, :platform_id, name: 'idx_bt_billing_tax_lines_platform'
    add_index :better_together_billing_tax_lines, :order_id, name: 'idx_bt_billing_tax_lines_order'
    add_index :better_together_billing_tax_lines, :line_item_id, name: 'idx_bt_billing_tax_lines_line_item'
    add_foreign_key :better_together_billing_tax_lines, :better_together_platforms, column: :platform_id
    add_foreign_key :better_together_billing_tax_lines, :better_together_billing_orders,
                    column: %i[order_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_tax_lines_order_platform'
    add_foreign_key :better_together_billing_tax_lines, :better_together_billing_line_items,
                    column: %i[line_item_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_tax_lines_line_item_platform'
    add_foreign_key :better_together_billing_tax_lines, :better_together_billing_tax_rates,
                    column: %i[tax_rate_id platform_id], primary_key: %i[id platform_id], name: 'fk_bt_billing_tax_lines_rate_platform'
  end

  # What an order and a line remember about tax, and the category a plan is sold under.
  def add_tax_columns
    add_order_tax_columns
    add_missing_column :better_together_billing_line_items, :tax_cents, :integer, null: false, default: 0
    add_missing_column :better_together_billing_line_items, :included_tax_cents, :integer, null: false, default: 0
    add_tax_category_column(:better_together_billing_line_items, 'idx_bt_billing_line_items_tax_category',
                            'fk_bt_billing_line_items_tax_category_platform')
    add_tax_category_column(:better_together_billing_plans, 'idx_bt_billing_plans_tax_category', 'fk_bt_billing_plans_tax_category_platform')
  end

  def add_order_tax_columns
    table = :better_together_billing_orders
    add_missing_column table, :tax_cents, :integer, null: false, default: 0
    add_missing_column table, :included_tax_cents, :integer, null: false, default: 0
    add_missing_column table, :tax_country_iso, :string
    add_missing_column table, :tax_region_code, :string
    add_tax_settlement_column(table)
    add_missing_column table, :prices_include_tax, :boolean
    return if column_exists?(table, :tax_registration_id)

    add_column table, :tax_registration_id, :uuid
    add_index table, :tax_registration_id, name: 'idx_bt_billing_orders_tax_registration'
    add_foreign_key table, :better_together_billing_tax_registrations, column: %i[tax_registration_id platform_id],
                                                                       primary_key: %i[id platform_id],
                                                                       name: 'fk_bt_billing_orders_tax_registration_platform'
  end

  def add_tax_settlement_column(table)
    return if column_exists?(table, :tax_settlement_id)

    add_column table, :tax_settlement_id, :uuid
    add_index table, :tax_settlement_id, name: 'idx_bt_billing_orders_tax_settlement'
    add_foreign_key table, :better_together_geography_settlements, column: :tax_settlement_id
  end

  def add_missing_column(table, column, type, **)
    add_column(table, column, type, **) unless column_exists?(table, column)
  end

  def add_tax_category_column(table, index_name, foreign_key_name)
    return if column_exists?(table, :tax_category_id)

    add_column table, :tax_category_id, :uuid
    add_index table, :tax_category_id, name: index_name
    add_foreign_key table, :better_together_billing_tax_categories, column: %i[tax_category_id platform_id],
                                                                    primary_key: %i[id platform_id], name: foreign_key_name
  end

  def remove_tax_columns # rubocop:disable Metrics/MethodLength
    {
      better_together_billing_orders: %i[tax_cents included_tax_cents tax_country_iso tax_region_code tax_settlement_id
                                         prices_include_tax tax_registration_id],
      better_together_billing_line_items: %i[tax_cents included_tax_cents tax_category_id],
      better_together_billing_plans: %i[tax_category_id]
    }.each do |table, columns|
      columns.each { |column| remove_column table, column if column_exists?(table, column) }
    end
  end
end
