# frozen_string_literal: true

class CreateBetterTogetherBillingSponsorships < ActiveRecord::Migration[7.2]
  def change
    # Guards table creation only — the unique token index below is guarded
    # separately, so an interrupted upgrade (table created, crash before the
    # index) can be retried safely instead of permanently skipping the index
    # has_secure_token relies on for DB-level token uniqueness.
    unless table_exists?(:better_together_billing_sponsorships)
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
    end

    return if index_name_exists?(:better_together_billing_sponsorships, 'idx_bt_billing_sponsorships_token')

    add_index :better_together_billing_sponsorships, :token, unique: true,
                                                             name: 'idx_bt_billing_sponsorships_token'
  end
end
