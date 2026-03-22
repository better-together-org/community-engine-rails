# frozen_string_literal: true

class CreateBetterTogetherChecklistItems < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :checklist_items do |t|
      t.bt_identifier
      t.bt_references :checklist, null: false, index: { name: 'by_checklist_item_checklist' },
                                  target_table: :better_together_checklists
      t.bt_creator
      t.bt_protected
      t.bt_privacy
      t.bt_position
    end

    add_index :better_together_checklist_items, %i[checklist_id position],
              name: 'index_checklist_items_on_checklist_id_and_position'
  end
end
