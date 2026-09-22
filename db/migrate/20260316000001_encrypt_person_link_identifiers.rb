# frozen_string_literal: true

# Widens identifier/name columns on person_links and person_access_grants from
# string (255 chars) to text so ActiveRecord::Encryption can store its JSON
# ciphertext envelope (which exceeds 255 chars for non-trivial values).
class EncryptPersonLinkIdentifiers < ActiveRecord::Migration[7.2]
  def change
    change_column :better_together_person_links, :remote_target_identifier, :text
    change_column :better_together_person_links, :remote_target_name, :text

    change_column :better_together_person_access_grants, :remote_grantee_identifier, :text
    change_column :better_together_person_access_grants, :remote_grantee_name, :text
  end
end
