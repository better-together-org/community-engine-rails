# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonSeedsController, :as_user do
  include Devise::Test::ControllerHelpers
  include Rails.application.routes.url_helpers
  include AutomaticTestConfiguration

  routes { BetterTogether::Engine.routes }

  let(:locale) { I18n.default_locale }
  let(:user)   { find_or_create_test_user('user@example.test', 'SecureTest123!@#', :user) }
  let(:person) { user.person }

  let(:other_user)   { create(:better_together_user, :confirmed) }
  let(:other_person) { other_user.person }

  # Seeds owned by the current person
  let(:creator_seed)  { create(:better_together_seed, :created_by_person, creator: person) }
  let(:seedable_seed) { create(:better_together_seed, :owned_as_seedable, person: person) }

  # Seed belonging to another person (used for IDOR tests)
  let(:other_seed) { create(:better_together_seed, :created_by_person, creator: other_person) }

  # ----------------------------------------------------------------
  # GET #index
  # ----------------------------------------------------------------
  describe 'GET #index' do
    before do
      creator_seed
      seedable_seed
      other_seed
    end

    it 'returns http success' do
      get :index, params: { locale: locale }
      expect(response).to have_http_status(:success)
    end

    it 'assigns only seeds owned by the current person' do
      get :index, params: { locale: locale }
      expect(assigns(:seeds)).to include(creator_seed, seedable_seed)
      expect(assigns(:seeds)).not_to include(other_seed)
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        get :index, params: { locale: locale }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  # ----------------------------------------------------------------
  # GET #show
  # ----------------------------------------------------------------
  describe 'GET #show' do
    it 'returns http success for a creator-owned seed' do
      get :show, params: { locale: locale, id: creator_seed.id }
      expect(response).to have_http_status(:success)
    end

    it 'returns http success for a seedable-owned seed' do
      get :show, params: { locale: locale, id: seedable_seed.id }
      expect(response).to have_http_status(:success)
    end

    it 'assigns the correct seed' do
      get :show, params: { locale: locale, id: creator_seed.id }
      expect(assigns(:seed)).to eq(creator_seed)
    end

    # IDOR: another person's seed ID must not leak via show
    it 'returns 404 for another person\'s seed (IDOR prevention)' do
      get :show, params: { locale: locale, id: other_seed.id }
      expect(response).to have_http_status(:not_found)
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        # Use a stub UUID — the controller redirects before any seed lookup,
        # so we don't need (or want) a real seed record here.
        get :show, params: { locale: locale, id: SecureRandom.uuid }
        expect(response).to have_http_status(:redirect)
      end
    end
  end

  # ----------------------------------------------------------------
  # POST #export
  # ----------------------------------------------------------------
  describe 'POST #export' do
    it 'creates a new Seed record for the current person' do
      expect do
        post :export, params: { locale: locale }
      end.to change(BetterTogether::Seed, :count).by(1)
    end

    it 'sets creator_id to the current person' do
      post :export, params: { locale: locale }
      expect(BetterTogether::Seed.last.creator_id).to eq(person.id)
    end

    it 'sets seedable to the current person' do
      post :export, params: { locale: locale }
      seed = BetterTogether::Seed.last
      expect(seed.seedable_type).to eq('BetterTogether::Person')
      expect(seed.seedable_id).to eq(person.id)
    end

    it 'redirects to person seeds path with notice' do
      post :export, params: { locale: locale }
      expect(response).to redirect_to(person_seeds_path(locale: locale))
      expect(flash[:notice]).to be_present
    end

    context 'when an export was already requested within the last hour' do
      before { create(:better_together_seed, :created_by_person, creator: person) }

      it 'does not create another Seed' do
        expect do
          post :export, params: { locale: locale }
        end.not_to change(BetterTogether::Seed, :count)
      end

      it 'redirects with an alert' do
        post :export, params: { locale: locale }
        expect(flash[:alert]).to be_present
      end
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        post :export, params: { locale: locale }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  # ----------------------------------------------------------------
  # DELETE #destroy
  # ----------------------------------------------------------------
  describe 'DELETE #destroy' do
    it 'destroys the seed' do
      seed_id = creator_seed.id
      expect do
        delete :destroy, params: { locale: locale, id: seed_id }
      end.to change(BetterTogether::Seed, :count).by(-1)
    end

    it 'redirects with a success notice' do
      delete :destroy, params: { locale: locale, id: creator_seed.id }
      expect(response).to redirect_to(person_seeds_path(locale: locale))
      expect(flash[:notice]).to be_present
    end

    # IDOR: destroy must not act on another person's seed
    it 'returns 404 for another person\'s seed (IDOR prevention)' do
      delete :destroy, params: { locale: locale, id: other_seed.id }
      expect(response).to have_http_status(:not_found)
    end

    it 'does not destroy the other person\'s seed on 404' do
      # Pin other_seed before measuring count — lazy evaluation inside the
      # expect block would create the record mid-measurement, inflating the count.
      other_seed_id = other_seed.id
      expect do
        delete :destroy, params: { locale: locale, id: other_seed_id }
      end.not_to change(BetterTogether::Seed, :count)
    end

    context 'when unauthenticated' do
      before { sign_out user }

      it 'redirects to sign-in' do
        # Use a stub UUID — the controller redirects before any seed lookup,
        # so we don't need (or want) a real seed record here.
        delete :destroy, params: { locale: locale, id: SecureRandom.uuid }
        expect(response).to have_http_status(:redirect)
      end
    end
  end
end
