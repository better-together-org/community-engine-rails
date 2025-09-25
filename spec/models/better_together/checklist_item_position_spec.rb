# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItem do
  # rubocop:todo RSpec/MultipleExpectations
  it 'assigns incremental position scoped by checklist and parent' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    checklist = create(:better_together_checklist)

    # create five existing top-level items
    5.times do |i|
      create(:better_together_checklist_item, checklist: checklist, position: i, privacy: 'public',
                                              label: "Existing #{i + 1}")
    end

    # create a new item without position - Positioned#set_position should set it to 5
    # create a new item without a preset position so Positioned#set_position runs
    new_item = build(:better_together_checklist_item, checklist: checklist, privacy: 'public',
                                                      label: 'Appended Model Item')
    # ensure factory default position (0) is not applied by setting to nil before save
    new_item.position = nil
    new_item.save!

    expect(new_item.position).to eq(5)

    # ordering check (use Ruby accessors because label is translated and not a DB column)
    ordered = checklist.checklist_items.order(:position).to_a.map { |ci| [ci.label, ci.position] }
    expect(ordered.last.first).to eq('Appended Model Item')
  end
end
