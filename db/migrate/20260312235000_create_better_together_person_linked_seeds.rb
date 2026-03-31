# frozen_string_literal: true

class CreateBetterTogetherPersonLinkedSeeds < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_person_linked_seeds)
      create_bt_table :person_linked_seeds do |t|
        t.references :person_access_grant, null: false, type: :uuid,
                                           foreign_key: { to_table: :better_together_person_access_grants }
        t.references :recipient_person, null: false, type: :uuid,
                                        foreign_key: { to_table: :better_together_people }
        t.references :source_platform, null: false, type: :uuid,
                                       foreign_key: { to_table: :better_together_platforms }
        t.string :identifier, null: false
        t.string :source_record_type, null: false
        t.string :source_record_id, null: false
        t.string :seed_type, null: false
        t.string :version, null: false
        t.string :privacy, null: false, default: 'private'
        t.text :payload, null: false
        t.datetime :source_updated_at
        t.datetime :last_synced_at
        t.jsonb :metadata, null: false, default: {}
      end
    end

    unless index_name_exists?(:better_together_person_linked_seeds, 'index_bt_person_linked_seeds_on_grant_and_identifier')
      add_index :better_together_person_linked_seeds,
                %i[person_access_grant_id identifier],
                unique: true,
                name: 'index_bt_person_linked_seeds_on_grant_and_identifier'
    end
    unless index_name_exists?(:better_together_person_linked_seeds, 'index_bt_person_linked_seeds_on_recipient_person_id')
      add_index :better_together_person_linked_seeds, :recipient_person_id,
                name: 'index_bt_person_linked_seeds_on_recipient_person_id'
    end
    return if index_name_exists?(:better_together_person_linked_seeds, 'index_bt_person_linked_seeds_on_source_platform_id')

    add_index :better_together_person_linked_seeds, :source_platform_id,
              name: 'index_bt_person_linked_seeds_on_source_platform_id'
  end
end
