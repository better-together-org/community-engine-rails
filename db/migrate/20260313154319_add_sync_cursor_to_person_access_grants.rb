# frozen_string_literal: true

class AddSyncCursorToPersonAccessGrants < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_person_access_grants, :sync_cursor, :string unless column_exists?(:better_together_person_access_grants,
                                                                                                  :sync_cursor)
  end
end
