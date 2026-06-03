# frozen_string_literal: true

class ExpandAuthorshipsIntoContributions < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_authorships, bulk: true do |t|
      t.string :role, null: false, default: 'author'
      t.string :contribution_type, null: false, default: 'content'
      t.jsonb :details, null: false, default: {}
    end

    add_index :better_together_authorships, :role, name: 'by_better_together_authorships_role'
    add_index :better_together_authorships,
              :contribution_type,
              name: 'by_better_together_authorships_contribution_type'
    add_index :better_together_authorships,
              %i[authorable_type authorable_id role],
              name: 'by_better_together_authorships_authorable_role'
  end
end
