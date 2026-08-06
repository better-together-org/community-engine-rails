# frozen_string_literal: true

# better_together_billing_events.beneficiary_type/beneficiary_id are read/written by
# BetterTogether::Billing::Event (belongs_to :beneficiary, polymorphic: true) but were
# never created by CreateBetterTogetherBillingTables/RecreateBetterTogetherBillingTables —
# spec/dummy/db/schema.rb only had them because a stale dev DB dump predated a migration
# edit. This adds the missing columns for real.
#
# community_id (+ its index/FK) on the same table is the mirror-image problem: it was
# removed from create_billing_events by a later in-place migration edit, but no migration
# ever dropped it from already-provisioned databases, so it lingers as dead/orphaned
# schema. No application code reads/writes community_id on Billing::Event (confirmed via
# repo-wide search) — safe to drop.
class ReconcileBetterTogetherBillingEventsBeneficiaryColumns < ActiveRecord::Migration[7.2]
  def change
    return unless table_exists?(:better_together_billing_events)

    unless column_exists?(:better_together_billing_events, :beneficiary_type)
      add_reference :better_together_billing_events, :beneficiary,
                    polymorphic: true, type: :uuid, index: false
    end

    unless index_exists?(:better_together_billing_events, %i[beneficiary_type beneficiary_id],
                         name: 'idx_bt_billing_events_beneficiary')
      add_index :better_together_billing_events, %i[beneficiary_type beneficiary_id],
                name: 'idx_bt_billing_events_beneficiary'
    end

    if foreign_key_exists?(:better_together_billing_events, column: :community_id)
      remove_foreign_key :better_together_billing_events, column: :community_id
    end

    if index_exists?(:better_together_billing_events, :community_id, name: 'idx_bt_billing_events_community')
      remove_index :better_together_billing_events, name: 'idx_bt_billing_events_community'
    end

    remove_column :better_together_billing_events, :community_id, :uuid if column_exists?(:better_together_billing_events, :community_id)
  end
end
