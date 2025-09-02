# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Nested Checklist Items', :as_platform_manager do
  let(:checklist) { create(:better_together_checklist) }
  # create a few items
  let!(:parent) { create(:better_together_checklist_item, checklist: checklist) }

  context 'when creating a nested child' do
    before do
      params = {
        better_together_checklist_item: {
          label: 'nested child',
          label_en: 'nested child',
          checklist_id: checklist.id,
          parent_id: parent.id
        }
      }

      post better_together.checklist_checklist_items_path(checklist),
           params: { checklist_item: params[:better_together_checklist_item] }

      # follow the controller redirect so any flash/alerts are available
      follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?
    end

    let(:created) do
      BetterTogether::ChecklistItem.where(checklist: checklist, parent: parent).find_by(label: 'nested child') ||
        BetterTogether::ChecklistItem.i18n.find_by(label: 'nested child')
    end

    it 'creates a child item under a parent' do
      expect(created).to be_present
    end

    it 'sets the parent id on the created child' do
      expect(created.parent_id).to eq(parent.id)
    end
  end

  context 'when reordering siblings' do
    let!(:a) { create(:better_together_checklist_item, checklist: checklist, parent: parent, position: 0) }
    let!(:b) { create(:better_together_checklist_item, checklist: checklist, parent: parent, position: 1) }
    let!(:top) { create(:better_together_checklist_item, checklist: checklist, position: 0) }

    before do
      ids = [b.id, a.id]
      patch better_together.reorder_checklist_checklist_items_path(checklist), params: { ordered_ids: ids }, as: :json
    end

    it 'responds with no content' do
      expect(response).to have_http_status(:no_content)
    end

    it 'moves the first sibling to position 1' do
      expect(a.reload.position).to eq(1)
    end

    it 'moves the second sibling to position 0' do
      expect(b.reload.position).to eq(0)
    end

    it 'does not affect top-level item position' do
      expect(top.reload.position).to eq(0)
    end
  end

  context 'when creating a localized child' do
    before do
      params = {
        checklist_item: {
          label_en: 'localized child',
          checklist_id: checklist.id,
          parent_id: parent.id
        }
      }

      post better_together.checklist_checklist_items_path(checklist), params: params
      follow_redirect! if respond_to?(:follow_redirect!) && response&.redirect?
    end

    let(:created_localized) do
      BetterTogether::ChecklistItem.where(checklist: checklist, parent: parent).find_by(label: 'localized child')
    end

    it 'creates a localized child record' do
      expect(created_localized).to be_present
    end

    it 'stores the localized label on the created child' do
      expect(created_localized.label).to eq('localized child')
    end
  end
end
