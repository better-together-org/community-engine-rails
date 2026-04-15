# frozen_string_literal: true

class CreateBetterTogetherJoatuSettlements < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_joatu_settlements)

    create_bt_table :joatu_settlements do |t|
      # The agreement this settlement closes (one settlement per agreement)
      t.references :agreement, type: :uuid, null: false,
                               foreign_key: { to_table: :better_together_joatu_agreements,
                                              on_delete: :restrict },
                               index: { unique: true, name: 'idx_bt_joatu_settlements_agreement' }

      # The party paying C3 (polymorphic — typically the Joatu::Request creator)
      t.references :payer, polymorphic: true, type: :uuid, null: false,
                           index: { name: 'idx_bt_joatu_settlements_payer' }

      # The party receiving C3 (polymorphic — typically the Joatu::Offer creator)
      t.references :recipient, polymorphic: true, type: :uuid, null: false,
                               index: { name: 'idx_bt_joatu_settlements_recipient' }

      # The C3::Token minted for the recipient upon completion (nullable until complete)
      t.references :c3_token, type: :uuid, null: true,
                              foreign_key: { to_table: :better_together_c3_tokens,
                                             on_delete: :nullify },
                              index: { name: 'idx_bt_joatu_settlements_token' }

      t.bigint  :c3_millitokens, null: false, default: 0
      t.string  :status, null: false, default: 'pending' # pending | completed | cancelled
      t.datetime :completed_at
    end
  end
end
