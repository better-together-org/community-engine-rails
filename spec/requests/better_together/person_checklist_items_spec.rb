require 'rails_helper'

RSpec.describe BetterTogether::PersonChecklistItemsController, type: :request do
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let!(:person) { create(:better_together_person, user: user) }
  let(:checklist) { create(:better_together_checklist) }
  let(:items) { create_list(:better_together_checklist_item, 3, checklist: checklist) }

  before do
    # Use project's HTTP login helper to satisfy route constraints
    test_user = find_or_create_test_user(user.email, 'password12345', :user)
    login(test_user.email, 'password12345')
  end

  it 'returns empty record when none exists and can create a completion' do
    get "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{checklist.id}/checklist_items/#{items.first.id}/person_checklist_item"
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['completed_at']).to be_nil

    patch "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{checklist.id}/checklist_items/#{items.first.id}/person_checklist_item",
          params: { completed: true }
    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)
    expect(data['completed_at']).not_to be_nil
  end
end
