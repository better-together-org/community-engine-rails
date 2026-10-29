# frozen_string_literal: true

# Table name is singular ("quota", not "quotas") deliberately: this app's inflections
# resolve "quota".pluralize to "quota" unchanged (verified: Rails' own default,
# unconfigured ActiveRecord::Base.table_name for a class named Quota is "quota" too),
# so this matches what Rails already infers rather than fighting it with an override.
class CreateBetterTogetherQuota < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_quota)

    create_bt_table :quota do |t|
      t.bt_references :owner, polymorphic: true, null: false,
                              index: { name: 'index_bt_quota_on_owner' }
      t.string :quota_type, null: false
      t.bigint :limit, null: false
      t.bigint :soft_limit
      t.string :period, null: false, default: 'cumulative'
      t.string :status, null: false, default: 'active'
      t.string :enforcement_mode, null: false, default: 'shadow'
      t.jsonb :metadata, null: false, default: {}
      # index: false here: a bare `t.bt_references :platform` on this table's own
      # implicit index silently ignores any custom `index: { name: ... }` passed inline
      # (reproduced even bypassing bt_references with plain `t.references`) and falls
      # back to the auto-generated "index_better_together_quotas_on_platform_id" —
      # pluralized, unlike every other explicitly-named index here. A separate
      # table-level add_index below, same as the one two lines down, isn't affected.
      t.bt_references :platform, null: true, index: false
    end

    add_index :better_together_quota, %i[owner_type owner_id quota_type],
              unique: true, name: 'index_bt_quota_on_owner_and_type'
    add_index :better_together_quota, :platform_id, name: 'index_bt_quota_on_platform'
  end
end
