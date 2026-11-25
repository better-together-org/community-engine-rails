# frozen_string_literal: true

# Directed, typed join between two platforms. Relation 'manages': the operator platform may act on the
# managed platform within granted scopes. The primary key is the identity shared with a mirror row.
class CreateBetterTogetherPlatformAssociations < ActiveRecord::Migration[7.2]
  TABLE = :better_together_platform_associations
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

    create_bt_table :platform_associations do |t|
      t.bt_references :operator_platform, target_table: PLATFORMS, null: false,
                                          index: { name: 'idx_bt_plat_assoc_operator' }
      t.bt_references :managed_platform, target_table: PLATFORMS, null: false,
                                         index: { name: 'idx_bt_plat_assoc_managed' }
      t.bt_references :delegated_from, target_table: TABLE, null: true, index: { name: 'idx_bt_plat_assoc_parent' }
      t.bt_references :requested_by, target_table: :better_together_people, null: true,
                                     index: { name: 'idx_bt_plat_assoc_requested_by' }
      t.bt_references :accepted_by, target_table: :better_together_people, null: true,
                                    index: { name: 'idx_bt_plat_assoc_accepted_by' }
      t.bt_references :status_changed_by, target_table: :better_together_people, null: true,
                                          index: { name: 'idx_bt_plat_assoc_changed_by' }
      t.string :status, null: false, default: 'requested'
      t.string :relation, null: false, default: 'manages'
      t.string :transport, null: false, default: 'direct'
      t.jsonb :granted_scopes, null: false, default: []
      t.datetime :expires_at
      t.datetime :accepted_at
      t.datetime :status_changed_at
    end
  end

  def add_indexes
    add_index TABLE, %i[operator_platform_id managed_platform_id relation], unique: true, name: 'idx_bt_plat_assoc_edge',
                                                                            if_not_exists: true
    add_index TABLE, :status, name: 'idx_bt_plat_assoc_status', if_not_exists: true
  end
end
