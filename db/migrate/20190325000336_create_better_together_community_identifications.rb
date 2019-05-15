class CreateBetterTogetherCommunityIdentifications < ActiveRecord::Migration[5.2]
  def change
    create_table :better_together_community_identifications do |t|
      t.boolean :active,
                  index: {
                    name: 'by_active_state'
                  },
                  null: false
      t.references :identity,
                  polymorphic: true,
                  index: {
                    name: 'by_identity'
                  },
                  null: false
      t.references :agent,
                  polymorphic: true,
                  index: {
                    name: 'by_agent'
                  },
                  null: false

      t.timestamps null:false

      t.index %i(identity_type identity_id agent_type agent_id),
              unique: true,
              name: 'unique_identification'

      t.index %i(active agent_type agent_id),
              unique: true,
              name: 'active_identification'
    end
  end
end
