class CreateBetterTogetherIdentifications < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :identifications do |t|
      t.boolean :active, index: { name: 'by_active_state' }, null: false

      # Using bt_references for polymorphic references
      t.bt_references :identity, polymorphic: true, null: false, index: { name: 'by_identity' }
      t.bt_references :agent, polymorphic: true, null: false, index: { name: 'by_agent' }

      # byebug
      # Additional indexes
      t.index %i(identity_type identity_id agent_type agent_id),
              unique: true,
              name: 'unique_identification'
      t.index %i(active agent_type agent_id),
              unique: true,
              name: 'active_identification'

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
