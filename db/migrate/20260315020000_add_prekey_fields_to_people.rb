# frozen_string_literal: true

# Adds Signal Protocol identity key and prekey fields to BetterTogether::Person.
# These fields store public key material only — private keys never leave the browser.
class AddPrekeyFieldsToPeople < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_people, :identity_key_public,  :text,    comment: 'Signal identity public key (base64)'
    add_column :better_together_people, :signed_prekey_id,     :integer, comment: 'Current signed prekey ID'
    add_column :better_together_people, :signed_prekey_public, :text,    comment: 'Signed prekey public key (base64)'
    add_column :better_together_people, :signed_prekey_sig,    :text,    comment: 'Signed prekey signature (base64)'
    add_column :better_together_people, :registration_id,      :integer, comment: 'Signal registration ID'

    add_index :better_together_people, :registration_id, unique: true, where: 'registration_id IS NOT NULL'
  end
end
