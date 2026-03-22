# frozen_string_literal: true

class CreateBetterTogetherPersonLinks < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :person_links do |t|
      t.references :platform_connection, null: false, type: :uuid,
                                         foreign_key: { to_table: :better_together_platform_connections }
      t.references :source_person, null: false, type: :uuid,
                                   foreign_key: { to_table: :better_together_people }
      t.references :target_person, null: true, type: :uuid,
                                   foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'pending'
      t.string :remote_target_identifier
      t.string :remote_target_name
      t.datetime :verified_at
      t.datetime :revoked_at
      t.jsonb :settings, null: false, default: {}
    end

    add_index :better_together_person_links,
              %i[platform_connection_id source_person_id target_person_id],
              unique: true,
              name: 'index_bt_person_links_on_connection_and_people'
    add_index :better_together_person_links, :status
  end
end
