# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonChecklistItemsController, :as_user do # rubocop:todo RSpec/SpecFilePathFormat
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user) }
  let!(:person) { create(:better_together_person, user: user) }
  let(:checklist) { create(:better_together_checklist) }
  let(:items) { create_list(:better_together_checklist_item, 3, checklist: checklist) }

  before do
    configure_host_platform
    # Use project's HTTP login helper to satisfy route constraints
    test_user = find_or_create_test_user(user.email, 'password12345', :user)
    login(test_user.email, 'password12345')
  end

  # rubocop:todo RSpec/MultipleExpectations
  it 'returns empty record when none exists and can create a completion' do # rubocop:todo RSpec/MultipleExpectations
    # rubocop:enable RSpec/MultipleExpectations
    # rubocop:todo Layout/LineLength
    get "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{checklist.id}/checklist_items/#{items.first.id}/person_checklist_item"
    # rubocop:enable Layout/LineLength
    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body)['completed_at']).to be_nil

    # rubocop:todo Layout/LineLength
    post "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{checklist.id}/checklist_items/#{items.first.id}/person_checklist_item",
         # rubocop:enable Layout/LineLength
         params: { completed: true }, as: :json
    expect(response).to have_http_status(:ok)
    data = JSON.parse(response.body)
    expect(data['completed_at']).not_to be_nil

    # Expect flash payload for client-side display
    expect(data['flash']).to be_present
    expect(data['flash']['type']).to eq('notice')
    expect(data['flash']['message']).to eq(I18n.t('flash.checklist_item.updated'))
  end
end
