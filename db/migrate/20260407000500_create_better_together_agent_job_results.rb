# frozen_string_literal: true

class CreateBetterTogetherAgentJobResults < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_agent_job_results)

    create_bt_table :agent_job_results do |t|
      t.string :job_id, null: false         # borgberry job_id (e.g. job-20260407-ffmpeg-001)
      t.string :job_type, null: false       # transcription, embedding, inference, etc.
      t.string :source_system, default: 'borgberry', null: false

      # Executing node
      t.string :node_id
      t.references :fleet_node, type: :uuid, null: true,
                                foreign_key: { to_table: :better_together_fleet_nodes, on_delete: :nullify },
                                index: { name: 'idx_bt_agent_job_results_fleet_node' }

      # Submitter (Person or AgentActor)
      t.references :submitter, polymorphic: true, type: :uuid,
                               index: { name: 'idx_bt_agent_job_results_submitter' }

      # Result payload
      t.jsonb :result_payload, null: false, default: {}
      t.jsonb :steps, null: false, default: []
      t.integer :elapsed_ms

      # Lifecycle
      t.string :status, null: false, default: 'pending' # pending, running, completed, failed
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
    end

    add_index :better_together_agent_job_results, :job_id,
              unique: true, name: 'idx_bt_agent_job_results_job_id'
    add_index :better_together_agent_job_results, :status,
              name: 'idx_bt_agent_job_results_status'
    add_index :better_together_agent_job_results, :node_id,
              name: 'idx_bt_agent_job_results_node_id'
  end
end
