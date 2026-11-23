# frozen_string_literal: true

# Directed join between two platforms: the operator platform may act on the managed platform within
# granted scopes. The platform_id column (PlatformRecord) always equals managed_platform_id.
class CreateBetterTogetherPlatformManagements < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platform_managements
  PLATFORMS = :better_together_platforms

  def up
    create_table_unless_exists
    add_indexes
  end

  def down
    drop_table TABLE if table_exists?(TABLE)
  end

  private

  def create_table_unless_exists
    return if table_exists?(TABLE)

    create_bt_table :platform_managements do |t|
      t.bt_references :operator_platform, target_table: PLATFORMS, null: false,
                                          index: { name: 'idx_bt_platform_mgmt_operator' }
      t.bt_references :managed_platform, target_table: PLATFORMS, null: false,
                                         index: { name: 'idx_bt_platform_mgmt_managed' }
      t.bt_references :platform, target_table: PLATFORMS, null: false,
                                 index: { name: 'idx_bt_platform_mgmt_platform' }
      t.bt_references :delegated_from, target_table: TABLE, null: true, index: { name: 'idx_bt_platform_mgmt_parent' }
      t.bt_references :requested_by, target_table: :better_together_people, null: true,
                                     index: { name: 'idx_bt_platform_mgmt_requested_by' }
      t.bt_references :accepted_by, target_table: :better_together_people, null: true,
                                    index: { name: 'idx_bt_platform_mgmt_accepted_by' }
      t.bt_references :status_changed_by, target_table: :better_together_people, null: true,
                                          index: { name: 'idx_bt_platform_mgmt_changed_by' }
      t.string :status, null: false, default: 'requested'
      t.string :transport, null: false, default: 'direct'
      t.jsonb :granted_scopes, null: false, default: []
      t.uuid :edge_uid, null: false, default: -> { 'gen_random_uuid()' }
      t.datetime :expires_at
      t.datetime :accepted_at
      t.datetime :status_changed_at
    end
  end

  def add_indexes
    add_index TABLE, %i[operator_platform_id managed_platform_id], unique: true, name: 'idx_bt_platform_mgmt_edge',
                                                                   if_not_exists: true
    add_index TABLE, :edge_uid, unique: true, name: 'idx_bt_platform_mgmt_edge_uid', if_not_exists: true
    add_index TABLE, :status, name: 'idx_bt_platform_mgmt_status', if_not_exists: true
  end
end
