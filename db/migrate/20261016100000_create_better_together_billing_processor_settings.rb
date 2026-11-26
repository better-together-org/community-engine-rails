# frozen_string_literal: true

# Which payment methods outside a vendor (cash, cheque, e-transfer) a platform or seller has
# switched on, and what buyers are told so they can pay. Final state; guarded so a re-run is
# a no-op.
#
# * platform_id NOT NULL; seller empty means the platform itself, otherwise a community or
#   person on the platform (types are checked by the model). One row per (seller, method),
#   so two partial unique indexes stand in for one (a plain index treats every NULL seller
#   as different).
# * enabled defaults to false: the methods are installed for everyone but work for a seller
#   only after a steward turns them on and acknowledges the drawbacks (acknowledged_at /
#   acknowledged_by_id).
# * settings is `text` because the model encrypts it (BetterTogether::Billing::EncryptedAttributes):
#   it holds where to send a cheque or which e-transfer address to pay, so it is never stored
#   in clear text, never logged, and shown only to the seller and to a buyer on their own order.
# * grant_on says when a buyer's access starts: confirmed (the seller says the money arrived)
#   or, for a cheque, received or cleared.
class CreateBetterTogetherBillingProcessorSettings < ActiveRecord::Migration[7.2]
  TABLE = :better_together_billing_processor_settings

  def up
    return if table_exists?(TABLE)

    create_bt_table :billing_processor_settings do |t|
      t.references :platform, null: false, type: :uuid, index: { name: 'idx_bt_billing_proc_settings_platform' },
                              foreign_key: { to_table: :better_together_platforms }
      t.string :seller_type
      t.uuid :seller_id
      t.string :processor, null: false
      t.boolean :enabled, null: false, default: false
      t.integer :hold_hours, null: false, default: 72
      t.string :grant_on
      t.string :purposes, array: true, null: false, default: %w[subscription one_time ticket exchange]
      t.text :settings, null: false
      t.datetime :acknowledged_at
      t.references :acknowledged_by, type: :uuid, index: { name: 'idx_bt_billing_proc_settings_ack_by' },
                                     foreign_key: { to_table: :better_together_people, on_delete: :nullify }
    end

    add_indexes
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def add_indexes
    add_index TABLE, %i[platform_id processor], unique: true, where: 'seller_id IS NULL',
                                                name: 'idx_bt_billing_proc_settings_platform_method'
    add_index TABLE, %i[platform_id seller_type seller_id processor], unique: true, where: 'seller_id IS NOT NULL',
                                                                      name: 'idx_bt_billing_proc_settings_seller_method'
    add_index TABLE, %i[seller_type seller_id], name: 'idx_bt_billing_proc_settings_seller'
    add_index TABLE, :enabled, name: 'idx_bt_billing_proc_settings_enabled'
  end
end
