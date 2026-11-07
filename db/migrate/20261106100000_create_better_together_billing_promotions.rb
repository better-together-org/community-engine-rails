# frozen_string_literal: true

# Promotion codes that give store credit. Final state; guarded so a re-run, or an interrupted earlier run,
# is a no-op for what exists.
#
# * promotions: what a code gives (an amount of credit, how long it lasts, what it may pay for), and its
#   limits (window, total redemptions, new members only). The code itself is NEVER stored: only a keyed
#   digest (HMAC-SHA256 with a key derived from the application secret), unique per platform. The code is
#   shown once, when the promotion is made.
# * promotion_redemptions: one per person per promotion (unique), tying the person to the credit lot the
#   redemption made.
#
# platform_id is NOT NULL, and the redemption's links to its promotion and lot are COMPOSITE foreign keys
# with the platform, so a row can never point at another platform's.
class CreateBetterTogetherBillingPromotions < ActiveRecord::Migration[7.2]
  def up
    create_promotions
    create_promotion_redemptions
  end

  def down
    %i[billing_promotion_redemptions billing_promotions].each do |name|
      table = :"better_together_#{name}"
      drop_table table, force: :cascade if table_exists?(table)
    end
  end

  private

  def create_promotions
    return if table_exists?(:better_together_billing_promotions)

    create_bt_table :billing_promotions do |t|
      t.uuid :platform_id, null: false
      t.references :created_by, type: :uuid, index: false, foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :name, null: false
      t.string :code_digest, null: false
      t.bigint :amount_cents, null: false
      t.string :currency, null: false
      t.integer :credit_expires_after_days
      t.string :purposes, array: true, null: false, default: []
      t.datetime :starts_at
      t.datetime :ends_at
      t.integer :max_redemptions
      t.integer :redemptions_count, null: false, default: 0
      t.boolean :new_members_only, null: false, default: false
      t.boolean :active, null: false, default: true
    end
    add_promotion_indexes
  end

  def add_promotion_indexes
    table = :better_together_billing_promotions
    add_index table, :platform_id, name: 'idx_bt_billing_promotions_platform'
    add_index table, :created_by_id, name: 'idx_bt_billing_promotions_created_by'
    add_index table, %i[platform_id code_digest], unique: true, name: 'idx_bt_billing_promotions_code'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_promotions_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_check_constraint table, 'amount_cents > 0', name: 'chk_bt_billing_promotions_amount'
    add_check_constraint table, 'credit_expires_after_days IS NULL OR credit_expires_after_days > 0', name: 'chk_bt_billing_promotions_days'
    add_check_constraint table, 'max_redemptions IS NULL OR (max_redemptions > 0 AND redemptions_count <= max_redemptions)',
                         name: 'chk_bt_billing_promotions_cap'
    add_check_constraint table, 'redemptions_count >= 0', name: 'chk_bt_billing_promotions_count'
  end

  def create_promotion_redemptions
    return if table_exists?(:better_together_billing_promotion_redemptions)

    create_bt_table :billing_promotion_redemptions do |t|
      t.uuid :platform_id, null: false
      t.uuid :promotion_id, null: false
      t.uuid :credit_lot_id, null: false
      t.references :person, type: :uuid, index: false, foreign_key: { to_table: :better_together_people, on_delete: :nullify }
    end
    table = :better_together_billing_promotion_redemptions
    add_index table, :platform_id, name: 'idx_bt_billing_promo_redemptions_platform'
    add_index table, :person_id, name: 'idx_bt_billing_promo_redemptions_person'
    add_index table, %i[promotion_id person_id], unique: true, name: 'idx_bt_billing_promo_redemptions_once'
    add_index table, :credit_lot_id, unique: true, name: 'idx_bt_billing_promo_redemptions_lot'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_promotions, column: %i[promotion_id platform_id], primary_key: %i[id platform_id],
                                                                name: 'fk_bt_billing_promo_redemptions_promotion_platform'
    add_foreign_key table, :better_together_billing_credit_lots, column: %i[credit_lot_id platform_id], primary_key: %i[id platform_id],
                                                                 name: 'fk_bt_billing_promo_redemptions_lot_platform'
  end
end
