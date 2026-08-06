# frozen_string_literal: true

# better_together_joatu_service_credit_balances is a ghost table — present in
# schema.rb with zero corresponding migration in history and zero code
# references anywhere (no model, route, or controller). It was never actually
# built; the repo's own design doc (docs/c3-contribution-integration-design.md
# §3.2) recommends retiring it in favor of a JSONAPI resource delegating to
# C3::Balance, which is a separate feature request, not part of this cleanup.
# This migration only restores schema.rb <-> migration-history parity.
class DropOrphanedJoatuServiceCreditBalances < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_joatu_service_credit_balances)

    drop_table :better_together_joatu_service_credit_balances
  end

  def down
    return if table_exists?(:better_together_joatu_service_credit_balances)

    create_bt_table :joatu_service_credit_balances do |t|
      t.references :agreement, type: :uuid, null: false, index: { unique: true, name: 'bt_joatu_service_credit_balances_by_agreement' }
      t.string :unit_type, null: false
      t.decimal :purchased_units, precision: 10, scale: 2, default: '0.0', null: false
      t.decimal :consumed_units, precision: 10, scale: 2, default: '0.0', null: false
      t.boolean :active, default: true, null: false
    end
  end
end
