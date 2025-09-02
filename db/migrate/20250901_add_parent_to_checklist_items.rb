# frozen_string_literal: true

class AddParentToChecklistItems < ActiveRecord::Migration[7.1]
  def change
    add_reference :better_together_checklist_items,
                  :parent,
                  type: :uuid,
                  foreign_key: { to_table: :better_together_checklist_items },
                  index: true
  end
end
