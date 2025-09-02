require 'rails_helper'

RSpec.describe BetterTogether::ChecklistItemsHelper, type: :helper do
  include BetterTogether::ChecklistItemsHelper

  let(:checklist) { create(:better_together_checklist) }

  it 'builds option title with depth prefix and slug' do
    parent = create(:better_together_checklist_item, checklist: checklist, label: 'Parent', slug: 'parent-slug')
    child = create(:better_together_checklist_item, checklist: checklist, parent: parent, label: 'Child', slug: 'child-slug')

    # stub depth to 1 for child (depends on model depth method)
    allow(child).to receive(:depth).and_return(1)

    expect(checklist_item_option_title(parent)).to include('Parent')
    expect(checklist_item_option_title(parent)).to include('(parent-slug)')

    expect(checklist_item_option_title(child)).to include('— Child')
    expect(checklist_item_option_title(child)).to include('(child-slug)')
  end
end
