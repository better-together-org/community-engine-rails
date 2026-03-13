# frozen_string_literal: true

class AddSyncCursorToPersonAccessGrants < ActiveRecord::Migration[8.0]
  def change
    add_column :better_together_person_access_grants, :sync_cursor, :string
  end
end
