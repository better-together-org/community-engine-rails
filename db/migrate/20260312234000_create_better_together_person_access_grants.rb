# frozen_string_literal: true

class CreateBetterTogetherPersonAccessGrants < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :person_access_grants do |t|
      t.references :person_link, null: false, type: :uuid,
                                 foreign_key: { to_table: :better_together_person_links }
      t.references :grantor_person, null: false, type: :uuid,
                                    foreign_key: { to_table: :better_together_people }
      t.references :grantee_person, null: true, type: :uuid,
                                    foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'pending'
      t.string :remote_grantee_identifier
      t.string :remote_grantee_name
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.datetime :expires_at
      t.jsonb :settings, null: false, default: {}
    end

    add_index :better_together_person_access_grants,
              %i[person_link_id grantor_person_id grantee_person_id],
              unique: true,
              name: 'index_bt_person_access_grants_on_link_and_people'
    add_index :better_together_person_access_grants, :status
  end
end
