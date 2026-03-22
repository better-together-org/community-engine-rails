# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonChecklistItemsController, :as_user do # rubocop:todo RSpec/SpecFilePathFormat
  include Devise::Test::IntegrationHelpers

  let(:user) { create(:user, :confirmed) }
  let!(:person) { create(:better_together_person, user: user) }
  let(:checklist) { create(:better_together_checklist) }
  let(:items) { create_list(:better_together_checklist_item, 3, checklist: checklist) }

  before do
    configure_host_platform
    # Use project's HTTP login helper to satisfy route constraints
    login(user.email, 'SecureTest123!@#')
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

  context 'with invalid checklist_id' do
    let(:invalid_id) { SecureRandom.uuid }

    # rubocop:todo RSpec/MultipleExpectations
    it 'returns 404 for show action' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      # rubocop:todo Layout/LineLength
      get "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{invalid_id}/checklist_items/#{items.first.id}/person_checklist_item"
      # rubocop:enable Layout/LineLength
      expect(response).to have_http_status(:not_found)
      data = JSON.parse(response.body)
      expect(data['error']).to eq('Checklist not found')
    end

    # rubocop:todo RSpec/MultipleExpectations
    it 'returns 404 for create action' do # rubocop:todo RSpec/MultipleExpectations
      # rubocop:enable RSpec/MultipleExpectations
      # rubocop:todo Layout/LineLength
      post "/#{I18n.default_locale}/#{BetterTogether.route_scope_path}/checklists/#{invalid_id}/checklist_items/#{items.first.id}/person_checklist_item",
           # rubocop:enable Layout/LineLength
           params: { completed: true }, as: :json
      expect(response).to have_http_status(:not_found)
      data = JSON.parse(response.body)
      expect(data['errors']).to include('Checklist not found')
    end
  end
end
