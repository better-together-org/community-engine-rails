# frozen_string_literal: true

class CreateBetterTogetherBillingSponsorships < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_billing_sponsorships)

    create_bt_table :billing_sponsorships do |t|
      t.string :token, null: false
      t.references :sponsor,
                   type: :uuid,
                   polymorphic: true,
                   null: false,
                   index: { name: 'idx_bt_billing_sponsorships_sponsor' }
      t.references :beneficiary,
                   type: :uuid,
                   polymorphic: true,
                   null: false,
                   index: { name: 'idx_bt_billing_sponsorships_beneficiary' }
      t.string :status, null: false, default: 'pending'
      t.datetime :accepted_at
      t.datetime :declined_at
      t.datetime :ended_at
      t.string :cancellation_reason
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_billing_sponsorships, :token, unique: true,
                                                             name: 'idx_bt_billing_sponsorships_token'
  end
end
