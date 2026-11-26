# frozen_string_literal: true

# What Community Engine knows about a subscription that Pay does not. Pay::Subscription stays THE
# subscription record (its status, period, trial and end columns are the truth); these two tables hold only
# what Pay has no place for. Final state; guarded so a re-run, or an interrupted earlier run, is a no-op.
#
# * subscription_terms: one per Pay subscription (unique). The plan it follows, who it is for (the
#   beneficiary, when not the payer), the method each renewal is paid by, the price it was sold at (a plan's
#   price change applies to new subscribers), the anchor that every period is counted from, and when the
#   unpaid grace ends.
# * subscription_periods: one per billing period of a subscription Community Engine renews itself (cash,
#   cheque, e-transfer, store credit), because Pay keeps only the current period. Unique per subscription and
#   sequence, which is what makes generating a renewal twice harmless. Each ties to the order that invoices it.
#
# platform_id is NOT NULL and the links to the Pay subscription, plan, terms and order are COMPOSITE foreign
# keys with the platform, so a row can never point at another platform's.
class CreateBetterTogetherBillingSubscriptions < ActiveRecord::Migration[7.2]
  def up
    create_subscription_terms
    create_subscription_periods
  end

  def down
    %i[billing_subscription_periods billing_subscription_terms].each do |name|
      table = :"better_together_#{name}"
      drop_table table, force: :cascade if table_exists?(table)
    end
  end

  private

  def create_subscription_terms
    return if table_exists?(:better_together_billing_subscription_terms)

    create_bt_table :billing_subscription_terms do |t|
      t.uuid :platform_id, null: false
      t.uuid :pay_subscription_id, null: false
      t.uuid :plan_id, null: false
      t.string :beneficiary_type
      t.uuid :beneficiary_id
      t.string :payment_method, null: false
      t.bigint :unit_amount_cents, null: false
      t.string :currency, null: false
      t.datetime :anchor_at, null: false
      t.integer :anchor_sequence, null: false, default: 0
      t.datetime :grace_ends_at
    end
    add_term_indexes
  end

  def add_term_indexes
    table = :better_together_billing_subscription_terms
    add_index table, :platform_id, name: 'idx_bt_billing_sub_terms_platform'
    add_index table, :pay_subscription_id, unique: true, name: 'idx_bt_billing_sub_terms_subscription'
    add_index table, :plan_id, name: 'idx_bt_billing_sub_terms_plan'
    add_index table, %i[beneficiary_type beneficiary_id], name: 'idx_bt_billing_sub_terms_beneficiary'
    add_index table, :grace_ends_at, where: 'grace_ends_at IS NOT NULL', name: 'idx_bt_billing_sub_terms_grace'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_sub_terms_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :pay_subscriptions, column: %i[pay_subscription_id platform_id], primary_key: %i[id platform_id],
                                               name: 'fk_bt_billing_sub_terms_subscription_platform'
    add_foreign_key table, :better_together_billing_plans, column: %i[plan_id platform_id], primary_key: %i[id platform_id],
                                                           name: 'fk_bt_billing_sub_terms_plan_platform'
    add_check_constraint table, 'unit_amount_cents >= 0 AND anchor_sequence >= 0', name: 'chk_bt_billing_sub_terms_amounts'
  end

  def create_subscription_periods
    return if table_exists?(:better_together_billing_subscription_periods)

    create_bt_table :billing_subscription_periods do |t|
      t.uuid :platform_id, null: false
      t.uuid :subscription_term_id, null: false
      t.uuid :order_id
      t.integer :sequence, null: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :status, null: false, default: 'pending'
      t.string :blocked_reason
      t.datetime :paid_at
    end
    add_period_indexes
  end

  def add_period_indexes
    table = :better_together_billing_subscription_periods
    add_index table, :platform_id, name: 'idx_bt_billing_sub_periods_platform'
    add_index table, %i[subscription_term_id sequence], unique: true, name: 'idx_bt_billing_sub_periods_sequence'
    add_index table, :order_id, unique: true, where: 'order_id IS NOT NULL', name: 'idx_bt_billing_sub_periods_order'
    add_index table, %i[status ends_at], name: 'idx_bt_billing_sub_periods_status_ends'
    add_index table, %i[id platform_id], unique: true, name: 'idx_bt_billing_sub_periods_id_platform'
    add_foreign_key table, :better_together_platforms, column: :platform_id
    add_foreign_key table, :better_together_billing_subscription_terms, column: %i[subscription_term_id platform_id],
                                                                        primary_key: %i[id platform_id],
                                                                        name: 'fk_bt_billing_sub_periods_term_platform'
    add_foreign_key table, :better_together_billing_orders, column: %i[order_id platform_id], primary_key: %i[id platform_id],
                                                            name: 'fk_bt_billing_sub_periods_order_platform'
    add_check_constraint table, 'sequence >= 0 AND ends_at > starts_at', name: 'chk_bt_billing_sub_periods_shape'
  end
end
