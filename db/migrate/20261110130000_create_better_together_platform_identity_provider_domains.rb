# frozen_string_literal: true

# Explicit allow-list of the platform domains (callback hosts) a provider configuration serves.
# A sign-in is valid only on a domain listed here; there is no implicit fallback.
class CreateBetterTogetherPlatformIdentityProviderDomains < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_identity_provider_domains)
      create_bt_table :platform_identity_provider_domains do |t|
        t.bt_references :platform_identity_provider, target_table: :better_together_platform_identity_providers,
                                                     index: { name: 'idx_bt_idp_domains_on_idp_id' }
        t.bt_references :platform_domain, target_table: :better_together_platform_domains,
                                          index: { name: 'idx_bt_idp_domains_on_domain_id' }
      end
    end

    return if index_name_exists?(:better_together_platform_identity_provider_domains, 'idx_bt_idp_domains_unique')

    add_index :better_together_platform_identity_provider_domains,
              %i[platform_identity_provider_id platform_domain_id],
              unique: true, name: 'idx_bt_idp_domains_unique'
  end
end
