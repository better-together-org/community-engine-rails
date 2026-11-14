# frozen_string_literal: true

# Delegation of authority from a human operator to a Robot on one platform,
# optionally limited to one community. Scopes reuse Doorkeeper scope names.
class CreateBetterTogetherAgentGrants < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_agent_grants)

    create_bt_table :agent_grants do |t|
      t.bt_references :robot, index: { name: 'idx_bt_agent_grants_robot' }
      t.bt_references :platform, index: { name: 'idx_bt_agent_grants_platform' }
      t.references :operator, type: :uuid, null: false, index: { name: 'idx_bt_agent_grants_operator' },
                              foreign_key: { to_table: :better_together_people, on_delete: :cascade }
      t.references :community, type: :uuid, null: true, index: { name: 'idx_bt_agent_grants_community' },
                               foreign_key: { to_table: :better_together_communities, on_delete: :cascade }
      t.references :granted_by, type: :uuid, null: true, index: { name: 'idx_bt_agent_grants_granted_by' },
                                foreign_key: { to_table: :better_together_people, on_delete: :nullify }
      t.string :scopes, array: true, null: false, default: []
      t.datetime :expires_at
      t.datetime :revoked_at
    end
  end
end
