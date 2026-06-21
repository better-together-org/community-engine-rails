# frozen_string_literal: true

class CreateBetterTogetherFeatureAccessGrants < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_feature_access_grants, id: :uuid do |t|
      t.integer :lock_version, null: false, default: 0
      t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms }
      t.references :person, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :granted_by_person, null: true, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :feature_key, null: false
      t.string :access_level, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.text :notes

      t.timestamps
    end

    add_index :better_together_feature_access_grants,
              %i[platform_id person_id feature_key],
              unique: true,
              where: '(revoked_at IS NULL)',
              name: 'index_bt_feature_access_grants_active_unique'
    add_index :better_together_feature_access_grants, :feature_key
    add_index :better_together_feature_access_grants, :expires_at
    add_index :better_together_feature_access_grants, :revoked_at
  end
end
