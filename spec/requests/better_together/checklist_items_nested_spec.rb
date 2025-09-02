# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nested Checklist Items', :as_platform_manager, type: :request do
  let(:checklist) { create(:better_together_checklist) }

  before do
    # create a few items
    @parent = create(:better_together_checklist_item, checklist: checklist)
    @child = create(:better_together_checklist_item, checklist: checklist, parent: @parent)
  end

  it 'creates a child item under a parent' do
    params = {
      better_together_checklist_item: {
        label: 'nested child',
        label_en: 'nested child',
        checklist_id: checklist.id,
        parent_id: @parent.id
      }
    }
    post better_together.checklist_checklist_items_path(checklist),
         params: { checklist_item: params[:better_together_checklist_item] }

    # follow the controller redirect so any flash/alerts are available
    follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?

    # Find the newly created child by parent to avoid translation lookup timing issues
    created = BetterTogether::ChecklistItem.where(parent: @parent).where.not(id: @child.id).first
    # Fallback to i18n finder if direct parent lookup fails
    created ||= BetterTogether::ChecklistItem.i18n.find_by(label: 'nested child')

    expect(created).to be_present
    expect(created.parent_id).to eq(@parent.id)
  end

  it 'orders siblings independently (sibling-scoped positions)' do
    # Create two siblings under same parent
    a = create(:better_together_checklist_item, checklist: checklist, parent: @parent, position: 0)
    b = create(:better_together_checklist_item, checklist: checklist, parent: @parent, position: 1)

    # Create another top-level item
    top = create(:better_together_checklist_item, checklist: checklist, position: 0)

    # Reorder siblings: move b before a
    ids = [b.id, a.id]
    patch better_together.reorder_checklist_checklist_items_path(checklist), params: { ordered_ids: ids }, as: :json

    expect(response).to have_http_status(:no_content)

    expect(a.reload.position).to eq(1)
    expect(b.reload.position).to eq(0)

    # Ensure top-level item position unaffected
    expect(top.reload.position).to eq(0)
  end

  it 'accepts localized keys (label_en) when creating a child' do
    params = {
      checklist_item: {
        label_en: 'localized child',
        checklist_id: checklist.id,
        parent_id: @parent.id
      }
    }

    post better_together.checklist_checklist_items_path(checklist), params: params
    follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?

    created = BetterTogether::ChecklistItem.where(parent: @parent).where.not(id: @child.id).first
    expect(created).to be_present
    expect(created.label).to eq('localized child')
  end
end
