# frozen_string_literal: true

# A provider uid is unique only within its provider platform: two OpenID Connect issuers may issue the same
# `sub`, so the identity key now includes the external provider platform (one per issuer).
class ScopePersonPlatformIntegrationUidToProviderPlatform < ActiveRecord::Migration[7.2]
  TABLE = :better_together_person_platform_integrations
  OLD_INDEX = 'idx_bt_ppi_provider_uid_local_platform'
  NEW_INDEX = 'idx_bt_ppi_provider_platform_uid_local'

  def up
    unless index_name_exists?(TABLE, NEW_INDEX)
      add_index TABLE, %i[provider platform_id uid local_platform_id], unique: true, name: NEW_INDEX
    end
    remove_index TABLE, name: OLD_INDEX if index_name_exists?(TABLE, OLD_INDEX)
  end

  def down
    unless index_name_exists?(TABLE, OLD_INDEX)
      add_index TABLE, %i[provider uid local_platform_id], unique: true, name: OLD_INDEX
    end
    remove_index TABLE, name: NEW_INDEX if index_name_exists?(TABLE, NEW_INDEX)
  end
end
