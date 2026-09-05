# frozen_string_literal: true

# Per-item x per-connection federation consent override. Absence of a grant
# for a given (federatable, platform_connection) pair means "defer to the
# item's federation_visibility tri-state" (see docs/plans/federation-item-consent.md).
class CreateBetterTogetherFederationContentGrants < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_federation_content_grants)

    create_bt_table :federation_content_grants do |t|
      t.bt_references :federatable, polymorphic: true, index: { name: 'bt_federation_content_grants_by_federatable' }
      t.bt_references :platform_connection, index: { name: 'bt_federation_content_grants_by_connection' }
      t.string :status, null: false, default: 'allowed'

      t.index %i[federatable_type federatable_id platform_connection_id],
              unique: true, name: 'bt_federation_content_grants_unique_pair'
    end
  end
end
