# frozen_string_literal: true

# One open (unrevoked) grant per robot, platform and community scope, so a
# credential can never resolve to an arbitrary one of several grants. Older
# duplicates are revoked, keeping the most recently updated.
class AddOpenGrantUniquenessToAgentGrants < ActiveRecord::Migration[7.2]
  INDEX = 'idx_bt_agent_grants_one_open'
  NIL_UUID = "'00000000-0000-0000-0000-000000000000'::uuid"
  SCOPE_KEY = "robot_id, platform_id, COALESCE(community_id, #{NIL_UUID})".freeze

  def up
    return unless table_exists?(:better_together_agent_grants)
    return if index_name_exists?(:better_together_agent_grants, INDEX)

    revoke_duplicate_open_grants
    execute <<~SQL.squish
      CREATE UNIQUE INDEX #{INDEX} ON better_together_agent_grants (#{SCOPE_KEY}) WHERE revoked_at IS NULL
    SQL
  end

  def down
    return unless index_name_exists?(:better_together_agent_grants, INDEX)

    remove_index :better_together_agent_grants, name: INDEX
  end

  private

  def revoke_duplicate_open_grants
    execute <<~SQL.squish
      UPDATE better_together_agent_grants SET revoked_at = NOW()
      WHERE id IN (
        SELECT id FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY #{SCOPE_KEY} ORDER BY updated_at DESC) AS position
          FROM better_together_agent_grants WHERE revoked_at IS NULL
        ) ranked WHERE position > 1
      )
    SQL
  end
end
