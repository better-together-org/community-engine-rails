# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItem, type: :model do
  it 'assigns incremental position scoped by checklist and parent' do
    checklist = create(:better_together_checklist)

    # create five existing top-level items
    5.times do |i|
      create(:better_together_checklist_item, checklist: checklist, position: i, privacy: 'public', label: "Existing #{i + 1}")
    end

    # create a new item without position - Positioned#set_position should set it to 5
    new_item = create(:better_together_checklist_item, checklist: checklist, privacy: 'public', label: 'Appended Model Item')

    expect(new_item.position).to eq(5)

    # ordering check
    ordered = checklist.checklist_items.order(:position).pluck(:label, :position)
    expect(ordered.last.first).to eq('Appended Model Item')
  end
end
