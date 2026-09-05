# frozen_string_literal: true

class RefactorPlatformDomainPrimaryToPrimaryFlag < ActiveRecord::Migration[7.2]
  def up
    unless column_exists?(:better_together_platform_domains, :primary_flag)
      add_column :better_together_platform_domains, :primary_flag, :boolean, null: false, default: false
    end

    if column_exists?(:better_together_platform_domains, :primary)
      execute 'UPDATE better_together_platform_domains SET primary_flag = better_together_platform_domains."primary"'
    end

    remove_index :better_together_platform_domains,
                 name: 'index_better_together_platform_domains_on_primary', if_exists: true

    unless index_name_exists?(:better_together_platform_domains,
                              'index_better_together_platform_domains_on_primary_flag')
      add_index :better_together_platform_domains, %i[platform_id primary_flag],
                unique: true,
                where: '"primary_flag" IS TRUE',
                name: 'index_better_together_platform_domains_on_primary_flag'
    end

    remove_column :better_together_platform_domains, :primary if column_exists?(:better_together_platform_domains, :primary)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
