# frozen_string_literal: true

# Lets a Doorkeeper application authenticate as a Robot (agent credential),
# optionally limited to one community. Applications without robot_id keep
# acting as their owner.
class AddAgentColumnsToOauthApplications < ActiveRecord::Migration[7.2]
  def change
    table = :better_together_oauth_applications

    unless column_exists?(table, :robot_id)
      add_reference table, :robot, type: :uuid, null: true, index: true,
                                   foreign_key: { to_table: :better_together_robots, on_delete: :cascade }
    end

    unless column_exists?(table, :community_id)
      add_reference table, :community, type: :uuid, null: true, index: true,
                                       foreign_key: { to_table: :better_together_communities, on_delete: :cascade }
    end

    add_column table, :last_used_at, :datetime unless column_exists?(table, :last_used_at)
    add_column table, :rotated_at, :datetime unless column_exists?(table, :rotated_at)
  end
end
