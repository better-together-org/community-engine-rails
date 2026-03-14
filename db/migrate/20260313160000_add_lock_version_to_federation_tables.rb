# frozen_string_literal: true

# Adds optimistic locking column (lock_version) to federation tables that were
# created with raw create_table instead of create_bt_table. This aligns them
# with the BetterTogether table convention.
class AddLockVersionToFederationTables < ActiveRecord::Migration[7.2]
  FEDERATION_TABLES = %w[
    better_together_platform_domains
    better_together_platform_connections
    better_together_person_links
    better_together_person_access_grants
    better_together_person_linked_seeds
    better_together_federation_access_tokens
  ].freeze

  def change
    FEDERATION_TABLES.each do |table|
      add_column table, :lock_version, :integer, null: false, default: 0 unless column_exists?(table, :lock_version)
    end
  end
end
