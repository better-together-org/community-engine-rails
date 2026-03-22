# frozen_string_literal: true

# Creates the one-time prekeys table for Signal Protocol X3DH sessions.
# One-time prekeys are consumed once (marked as consumed when served) and never reused.
class CreateBetterTogetherOneTimePrekeys < ActiveRecord::Migration[7.2]
  def change
    create_bt_table :one_time_prekeys do |t|
      # bt_references follows the repo convention: UUID FK to the namespaced table
      # with the correct index name. Do not use t.references here.
      t.bt_references :person, index: { name: 'bt_one_time_prekeys_by_person' }
      t.integer :key_id,     null: false,             comment: 'Signal prekey ID (scoped to person)'
      t.text    :public_key, null: false,             comment: 'Prekey public key (base64)'
      t.boolean :consumed,   default: false, null: false, comment: 'True after this key has been served once'
    end

    add_index :better_together_one_time_prekeys, %i[person_id key_id], unique: true
    add_index :better_together_one_time_prekeys, %i[person_id consumed]
  end
end
