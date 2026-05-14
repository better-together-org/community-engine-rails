# frozen_string_literal: true

class AddShareDomainToPlatformDomains < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_platform_domains, :share_domain)
      add_column :better_together_platform_domains, :share_domain, :boolean, null: false, default: false
    end

    # All existing records are single-domain-per-platform, so each is its own share domain.
    execute 'UPDATE better_together_platform_domains SET share_domain = TRUE'

    unless index_name_exists?(:better_together_platform_domains,
                              'index_better_together_platform_domains_on_share_domain')
      add_index :better_together_platform_domains, %i[platform_id share_domain],
                unique: true,
                where: '"share_domain" IS TRUE',
                name: 'index_better_together_platform_domains_on_share_domain'
    end
  end

  def down
    remove_index :better_together_platform_domains,
                 name: 'index_better_together_platform_domains_on_share_domain', if_exists: true
    remove_column :better_together_platform_domains, :share_domain if column_exists?(:better_together_platform_domains, :share_domain)
  end
end
