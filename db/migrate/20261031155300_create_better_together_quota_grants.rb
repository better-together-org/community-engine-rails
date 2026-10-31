# frozen_string_literal: true

class CreateBetterTogetherQuotaGrants < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota_grants)

    create_bt_table :quota_grants do |t|
      t.bt_references :owner, polymorphic: true, null: false,
                              index: { name: 'index_bt_quota_grants_on_owner' }
      t.string :quota_type, null: false
      t.bigint :limit, null: false
      t.bt_references :granted_by, polymorphic: true, null: true,
                                   index: { name: 'index_bt_quota_grants_on_granted_by' }
      t.text :reason
      t.datetime :expires_at
      t.bt_references :platform, null: true, index: { name: 'index_bt_quota_grants_on_platform' }
    end

    add_index :better_together_quota_grants, %i[owner_type owner_id quota_type],
              name: 'index_bt_quota_grants_on_owner_and_type'
  end
end
