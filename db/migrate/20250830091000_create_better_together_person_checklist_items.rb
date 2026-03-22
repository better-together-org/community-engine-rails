# frozen_string_literal: true

class CreateBetterTogetherPersonChecklistItems < ActiveRecord::Migration[7.0] # rubocop:todo Style/Documentation
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :person_checklist_items do |t|
      t.bt_references :person, null: false, target_table: :better_together_people,
                               index: { name: 'bt_person_checklist_items_on_person' }
      t.bt_references :checklist, null: false, target_table: :better_together_checklists,
                                  index: { name: 'bt_person_checklist_items_on_checklist' }
      t.bt_references :checklist_item, null: false, target_table: :better_together_checklist_items,
                                       index: { name: 'bt_person_checklist_items_on_checklist_item' }

      t.datetime :completed_at, index: true

      t.text :notes
    end

    # Ensure a person only has one record per checklist item
    add_index :better_together_person_checklist_items, %i[person_id checklist_item_id],
              name: 'bt_person_checklist_items_on_person_and_checklist_item', unique: true

    # Partial index for fast lookup of uncompleted items per person
    add_index :better_together_person_checklist_items, :person_id,
              name: 'bt_person_checklist_items_uncompleted_on_person_id', where: 'completed_at IS NULL'
  end
end
