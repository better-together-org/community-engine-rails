# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItemsHelper do
  include described_class

  let(:checklist) { create(:better_together_checklist) }

  it 'builds option title for a parent item with slug' do
    parent = create(:better_together_checklist_item, checklist: checklist, label: 'Parent', slug: 'parent-slug')

    expect(checklist_item_option_title(parent)).to match(/Parent.*\(parent-slug\)/)
  end

  it 'builds option title for a child item with depth prefix and slug' do
    parent = create(:better_together_checklist_item, checklist: checklist, label: 'Parent', slug: 'parent-slug')
    child = create(:better_together_checklist_item, checklist: checklist, parent: parent, label: 'Child',
                                                    slug: 'child-slug')

    # stub depth to 1 for child (depends on model depth method)
    allow(child).to receive(:depth).and_return(1)

    expect(checklist_item_option_title(child)).to match(/—\s+Child.*\(child-slug\)/)
  end
end
