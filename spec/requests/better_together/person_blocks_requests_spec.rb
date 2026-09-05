# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonBlocks', :as_user do
  let(:locale) { I18n.default_locale }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }
  let!(:blocked_person) { create(:better_together_person, name: 'Blocked Person', privacy: 'public') }
  let!(:other_blocked_person) { create(:better_together_person, name: 'Other Blocked Person', privacy: 'public') }
  let!(:searchable_person) { create(:better_together_person, name: 'Search Target', privacy: 'public') }
  let!(:person_block) { create(:person_block, blocker: person, blocked: blocked_person) }
  let!(:other_person_block) { create(:person_block, blocker: other_blocked_person, blocked: searchable_person) }

  describe 'GET /blocks' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_blocks_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows only the current person blocked people' do
      get better_together.person_blocks_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(blocked_person.name)
      expect(response.body).not_to include(searchable_person.name)
    end
  end

  describe 'GET /blocks/search' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        get better_together.search_person_blocks_path(locale:), params: { q: 'Search' }, as: :json
      end.to raise_error(ActionController::RoutingError)
    end

    it 'returns searchable people who are not already blocked' do
      get better_together.search_person_blocks_path(locale:), params: { q: 'Search' }, as: :json

      expect(response).to have_http_status(:ok)

      payload = JSON.parse(response.body)
      expect(payload.pluck('text')).to include(searchable_person.name)
      expect(payload.pluck('text')).not_to include(blocked_person.name)
      expect(payload.pluck('text')).not_to include(person.name)
    end
  end

  describe 'POST /blocks' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        post better_together.person_blocks_path(locale:), params: { person_block: { blocked_id: searchable_person.id } }
      end.to raise_error(ActionController::RoutingError)
    end

    it 'creates a new block for the current person' do
      expect do
        post better_together.person_blocks_path(locale:), params: { person_block: { blocked_id: searchable_person.id } }
      end.to change(BetterTogether::PersonBlock, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(better_together.person_blocks_path(locale:))
      expect(BetterTogether::PersonBlock.order(:created_at).last.blocker).to eq(person)
    end
  end

  describe 'DELETE /blocks/:id' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        delete better_together.person_block_path(person_block, locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'returns not found for another persons block' do
      delete better_together.person_block_path(other_person_block, locale:)

      expect(response).to have_http_status(:not_found)
      expect(other_person_block.reload).to be_present
    end
  end
end
