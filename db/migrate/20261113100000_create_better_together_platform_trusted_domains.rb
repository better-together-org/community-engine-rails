# frozen_string_literal: true

# Per-platform list of email domains whose verified addresses may register without an invitation.
class CreateBetterTogetherPlatformTrustedDomains < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_trusted_domains)
      create_bt_table :platform_trusted_domains do |t|
        t.bt_references :platform, target_table: :better_together_platforms,
                                   index: { name: 'idx_bt_trusted_domains_on_platform_id' }
        t.bt_references :role, target_table: :better_together_roles,
                               index: { name: 'idx_bt_trusted_domains_on_role_id' }
        t.bt_references :created_by, target_table: :better_together_people, null: true,
                                     index: { name: 'idx_bt_trusted_domains_on_created_by_id' }
        t.string  :domain, null: false
        t.boolean :enabled, null: false, default: true
        t.boolean :include_subdomains, null: false, default: false
        t.boolean :public_domain_confirmed, null: false, default: false
        t.boolean :role_ceiling_confirmed, null: false, default: false
        t.text    :note
      end
    end

    return if index_name_exists?(:better_together_platform_trusted_domains, 'idx_bt_trusted_domains_unique')

    add_index :better_together_platform_trusted_domains, %i[platform_id domain],
              unique: true, name: 'idx_bt_trusted_domains_unique'
  end
end
