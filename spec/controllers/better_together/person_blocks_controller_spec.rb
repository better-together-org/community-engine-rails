# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::PersonBlocksController, :as_platform_manager do
  include Devise::Test::ControllerHelpers
  include BetterTogether::DeviseSessionHelpers
  include Rails.application.routes.url_helpers

  routes { BetterTogether::Engine.routes }
  let(:locale) { I18n.default_locale }
  let(:user) { create(:better_together_user, :confirmed) }
  let(:person) { user.person }
  let(:blocked_person) { create(:better_together_person) }
  let(:another_person) { create(:better_together_person) }

  describe 'GET #search' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let!(:john_doe) { create(:better_together_person, name: 'John Doe', privacy: 'public') }

    it 'returns searchable people as JSON' do # rubocop:todo RSpec/ExampleLength, RSpec/MultipleExpectations
      get :search, params: { locale: locale, q: 'John' }, format: :json

      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq('application/json; charset=utf-8')

      json_response = JSON.parse(response.body)
      expect(json_response.first['text']).to eq('John Doe')
      expect(json_response.first['value']).to eq(john_doe.id.to_s)
    end

    it 'excludes already blocked people from search results' do # rubocop:todo RSpec/MultipleExpectations
      blocked_user = create(:better_together_person, name: 'Blocked User', privacy: 'public')
      create(:person_block, blocker: person, blocked: blocked_user)

      get :search, params: { locale: locale, q: 'Blocked' }, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to be_empty
    end

    it 'excludes current user from search results' do # rubocop:todo RSpec/MultipleExpectations
      get :search, params: { locale: locale, q: person.name }, format: :json

      expect(response).to have_http_status(:success)
      expect(JSON.parse(response.body)).to be_empty
    end

    it 'requires authentication' do
      sign_out user
      get :search, params: { locale: locale, q: 'John' }, format: :json
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    context 'when user has blocked people' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let!(:person_block) { create(:person_block, blocker: person, blocked: blocked_person) }

      it 'returns http success' do
        get :index, params: { locale: locale }
        expect(response).to have_http_status(:success)
      end

      it 'assigns @blocked_people' do
        get :index, params: { locale: locale }
        expect(assigns(:blocked_people)).to include(blocked_person)
      end

      # AC-2.3: I can view a list of users I have blocked
      it 'shows blocked users in the list' do
        get :index, params: { locale: locale }
        expect(assigns(:blocked_people)).to contain_exactly(blocked_person)
      end

      # AC-2.11: I can search through my blocked users by name
      it 'filters blocked users by search query' do
        get :index, params: { locale: locale, search: blocked_person.name }
        expect(assigns(:blocked_people)).to include(blocked_person)
      end

      it 'returns empty results for non-matching search' do
        get :index, params: { locale: locale, search: 'nonexistent' }
        expect(assigns(:blocked_people)).to be_empty
      end

      # AC-2.12: I can see when I blocked each user (FAILING - not implemented yet)
      it 'includes blocking timestamp information' do
        get :index, params: { locale: locale }
        expect(assigns(:person_blocks)).to include(person_block)
      end

      # AC-2.15: I can see how many users I have blocked (FAILING - not implemented yet)
      it 'provides blocked users count' do
        get :index, params: { locale: locale }
        expect(assigns(:blocked_count)).to eq(1)
      end
    end

    context 'when user has no blocked people' do
      it 'returns empty blocked_people' do
        get :index, params: { locale: locale }
        expect(assigns(:blocked_people)).to be_empty
      end

      it 'shows zero count' do
        get :index, params: { locale: locale }
        expect(assigns(:blocked_count)).to eq(0)
      end
    end

    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do # rubocop:todo RSpec/MultipleExpectations
        get :index, params: { locale: locale }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  describe 'GET #new' do
    # AC-2.13: I can block a user by entering their username or email (FAILING - not implemented yet)
    it 'returns http success' do
      get :new, params: { locale: locale }
      expect(response).to have_http_status(:success)
    end

    it 'assigns a new person_block' do
      get :new, params: { locale: locale }
      expect(assigns(:person_block)).to be_a_new(BetterTogether::PersonBlock)
    end

    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do # rubocop:todo RSpec/MultipleExpectations
        get :new, params: { locale: locale }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  describe 'POST #create' do
    context 'with valid params' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:valid_params) { { locale: locale, person_block: { blocked_id: blocked_person.id } } }

      # AC-2.1: I can block users from their profile page
      it 'creates a new PersonBlock' do
        expect do
          post :create, params: valid_params
        end.to change(BetterTogether::PersonBlock, :count).by(1)
      end

      # AC-2.9: I receive confirmation when blocking/unblocking users
      it 'sets success flash message' do
        post :create, params: valid_params
        expect(flash[:notice]).to match(/blocked/i)
      end

      it 'redirects to blocks path' do
        post :create, params: valid_params
        expect(response.location).to include('/blocks')
      end

      # Test AJAX responses for interactive interface (FAILING - not implemented yet)
      # rubocop:todo RSpec/NestedGroups
      context 'with AJAX request' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        it 'responds with turbo_stream' do
          post :create, params: valid_params, format: :turbo_stream
          expect(response.content_type).to include('text/vnd.turbo-stream.html')
        end
      end
    end

    context 'with invalid params' do
      # AC-2.8: I cannot block myself
      # rubocop:todo RSpec/NestedGroups
      context 'when trying to block self' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:invalid_params) { { locale: locale, person_block: { blocked_id: person.id } } }

        it 'does not create a PersonBlock' do
          expect do
            post :create, params: invalid_params
          end.not_to change(BetterTogether::PersonBlock, :count)
        end

        it 'sets error flash message' do
          post :create, params: invalid_params
          expect(flash[:alert]).to be_present
        end
      end

      # AC-2.7: I cannot block platform administrators
      # rubocop:todo RSpec/NestedGroups
      context 'when trying to block platform administrator' do # rubocop:todo RSpec/MultipleMemoizedHelpers, RSpec/NestedGroups
        # rubocop:enable RSpec/NestedGroups
        let(:platform_admin) { create(:better_together_person) }
        let(:invalid_params) { { locale: locale, person_block: { blocked_id: platform_admin.id } } }

        before do
          platform = BetterTogether::Platform.find_by(host: true) ||
                     create(:better_together_platform, host: true)
          role = BetterTogether::Role.find_by(identifier: 'platform_manager') ||
                 create(:better_together_role,
                        identifier: 'platform_manager',
                        resource_type: 'BetterTogether::Platform',
                        name: 'Platform Manager')

          create(:better_together_person_platform_membership,
                 member: platform_admin,
                 joinable: platform,
                 role: role)
        end

        it 'does not create a PersonBlock' do
          expect do
            post :create, params: invalid_params
          end.not_to change(BetterTogether::PersonBlock, :count)
        end

        it 'sets error flash message' do
          post :create, params: invalid_params
          expect(flash[:error]).to match(/not authorized/i)
        end
      end
    end

    # Test blocking by person ID (using the new select dropdown approach)
    context 'when blocking by person ID' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let!(:target_person) { create(:better_together_person, identifier: 'targetuser') }
      let(:valid_params) { { locale: locale, person_block: { blocked_id: target_person.id } } }

      it 'creates a new PersonBlock by person ID' do
        expect do
          post :create, params: valid_params
        end.to change(BetterTogether::PersonBlock, :count).by(1)
      end
    end

    context 'when not authenticated' do
      before { sign_out user }

      it 'redirects to sign in' do # rubocop:todo RSpec/MultipleExpectations
        post :create, params: { locale: locale, person_block: { blocked_id: blocked_person.id } }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end

  describe 'DELETE #destroy' do # rubocop:todo RSpec/MultipleMemoizedHelpers
    let!(:person_block) { create(:person_block, blocker: person, blocked: blocked_person) }

    # AC-2.4: I can unblock users from my block list
    it 'destroys the PersonBlock' do
      expect do
        delete :destroy, params: { locale: locale, id: person_block.id }
      end.to change(BetterTogether::PersonBlock, :count).by(-1)
    end

    # AC-2.9: I receive confirmation when blocking/unblocking users
    it 'sets success flash message' do
      delete :destroy, params: { locale: locale, id: person_block.id }
      expect(flash[:notice]).to match(/unblocked/i)
    end

    it 'redirects to blocks path' do
      delete :destroy, params: { locale: locale, id: person_block.id }
      expect(response.location).to include('/blocks')
    end

    # Test AJAX responses for interactive interface (FAILING - not implemented yet)
    context 'with AJAX request' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      it 'responds with turbo_stream' do
        delete :destroy, params: { locale: locale, id: person_block.id }, format: :turbo_stream
        expect(response.content_type).to include('text/vnd.turbo-stream.html')
      end
    end

    context 'when trying to destroy someone elses block' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      let(:other_persons_block) { create(:person_block, blocker: another_person, blocked: blocked_person) }

      it 'renders not found (404)' do
        delete :destroy, params: { locale: locale, id: other_persons_block.id }
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when not authenticated' do # rubocop:todo RSpec/MultipleMemoizedHelpers
      before { sign_out user }

      it 'redirects to sign in' do # rubocop:todo RSpec/MultipleExpectations
        delete :destroy, params: { locale: locale, id: person_block.id }
        expect(response).to have_http_status(:redirect)
        expect(response.location).to include('/users/sign-in')
      end
    end
  end
end
