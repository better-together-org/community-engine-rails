# frozen_string_literal: true

class CreateBetterTogetherPlatformDomains < ActiveRecord::Migration[7.2]
  def change
    create_table :better_together_platform_domains, id: :uuid, default: -> { 'gen_random_uuid()' } do |t|
      t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.string :hostname, null: false
      t.boolean :primary, null: false, default: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :better_together_platform_domains, 'lower(hostname)', unique: true,
                                                                    name: 'index_better_together_platform_domains_on_lower_hostname'
    add_index :better_together_platform_domains, %i[platform_id primary],
              unique: true,
              where: '"primary" IS TRUE',
              name: 'index_better_together_platform_domains_on_primary'
  end
end
