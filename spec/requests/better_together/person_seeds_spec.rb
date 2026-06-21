# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'BetterTogether::PersonSeeds', :as_user do
  let(:locale) { I18n.default_locale }
  let!(:user) { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }
  let(:other_user) { create(:better_together_user, :confirmed) }
  let!(:visible_seed) { create(:better_together_seed, :personal_export, person:) }
  let!(:other_seed) { create(:better_together_seed, :personal_export, person: other_user.person) }

  describe 'GET /my/seeds' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_seeds_path(locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows only the current person seeds' do
      get better_together.person_seeds_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(visible_seed.identifier)
      expect(response.body).not_to include(other_seed.identifier)
    end
  end

  describe 'GET /my/seeds/:id' do
    it 'returns 404 for unauthenticated users' do
      logout

      get better_together.person_seed_path(visible_seed, locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'shows the current person seed' do
      get better_together.person_seed_path(visible_seed, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(visible_seed.identifier)
    end

    it 'returns not found for another person seed' do
      get better_together.person_seed_path(other_seed, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'POST /my/seeds/export' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        post better_together.export_person_seeds_path(locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'queues a personal export seed for the current person' do
      BetterTogether::Seed.where(seedable: person).delete_all

      expect do
        post better_together.export_person_seeds_path(locale:)
      end.to change(BetterTogether::Seed, :count).by(1)

      expect(response).to have_http_status(:found)
      expect(response).to redirect_to(better_together.person_seeds_path(locale:))
      expect(BetterTogether::Seed.order(:created_at).last.seedable).to eq(person)
    end
  end

  describe 'DELETE /my/seeds/:id' do
    it 'raises a routing error for unauthenticated users because the route is constrained' do
      logout

      expect do
        delete better_together.person_seed_path(visible_seed, locale:)
      end.to raise_error(ActionController::RoutingError)
    end

    it 'deletes the current person seed' do
      expect do
        delete better_together.person_seed_path(visible_seed, locale:)
      end.to change(BetterTogether::Seed, :count).by(-1)

      expect(response).to have_http_status(:see_other)
      expect(response).to redirect_to(better_together.person_seeds_path(locale:))
    end

    it 'returns not found for another person seed' do
      delete better_together.person_seed_path(other_seed, locale:)

      expect(response).to have_http_status(:not_found)
      expect(other_seed.reload).to be_present
    end
  end
end
