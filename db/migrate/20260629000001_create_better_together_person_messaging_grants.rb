# frozen_string_literal: true

class CreateBetterTogetherPersonMessagingGrants < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_person_messaging_grants)

    create_bt_table :person_messaging_grants do |t|
      t.references :grantor,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_people, on_delete: :cascade },
                   index: false
      t.references :grantee,
                   type: :uuid,
                   null: false,
                   foreign_key: { to_table: :better_together_people, on_delete: :cascade },
                   index: false
    end

    add_index :better_together_person_messaging_grants,
              %i[grantor_id grantee_id],
              unique: true,
              name: 'idx_bt_messaging_grants_grantor_grantee'
    add_index :better_together_person_messaging_grants,
              :grantee_id,
              name: 'idx_bt_messaging_grants_grantee'
  end
end
