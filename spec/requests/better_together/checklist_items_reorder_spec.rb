# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'ChecklistItems Reorder' do
  let(:locale) { I18n.default_locale }
  let(:platform_manager) { find_or_create_test_user('manager@example.test', 'password12345', :platform_manager) }

  before do
    login(platform_manager.email, 'password12345')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'reorders items' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    checklist = create(:better_together_checklist, creator: platform_manager.person)
    item1 = create(:better_together_checklist_item, checklist: checklist, position: 0)
    item2 = create(:better_together_checklist_item, checklist: checklist, position: 1)
    item3 = create(:better_together_checklist_item, checklist: checklist, position: 2)

    ids = [item3.id, item1.id, item2.id]

    patch better_together.reorder_checklist_checklist_items_path(checklist, locale: locale),
          params: { ordered_ids: ids }, as: :json

    expect(response).to have_http_status(:no_content)

    expect(item3.reload.position).to eq(0)
    expect(item1.reload.position).to eq(1)
    expect(item2.reload.position).to eq(2)
  end
end
