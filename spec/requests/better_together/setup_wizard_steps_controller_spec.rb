# frozen_string_literal: true

require 'rails_helper'

module BetterTogether
  RSpec.describe SetupWizardStepsController, :skip_host_setup do
    let(:wizard) { create(:wizard, identifier: 'platform_setup') }
    let(:platform_details_step) do
      create(:wizard_step_definition,
             wizard:,
             identifier: 'platform_details',
             template: 'better_together/setup_wizard_steps/platform_details')
    end
    let(:admin_creation_step) do
      create(:wizard_step_definition,
             wizard:,
             identifier: 'admin_creation',
             template: 'better_together/setup_wizard_steps/admin_creation')
    end

    before do
      platform_details_step
      admin_creation_step
    end

    describe 'GET #platform_details' do
      before do
        get better_together.setup_wizard_step_platform_details_path(locale: I18n.default_locale)
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns @platform' do
        expect(assigns(:platform)).to be_a(Platform)
        expect(assigns(:platform)).to be_new_record
      end

      it 'assigns @form' do
        expect(assigns(:form)).to be_a(BetterTogether::HostPlatformDetailsForm)
      end

      it 'sets default platform attributes' do
        platform = assigns(:platform)
        expect(platform.privacy).to eq('private')
        expect(platform.protected).to be true
        expect(platform.host).to be true
      end
    end

    describe 'POST #create_host_platform' do
      let(:valid_platform_params) do
        {
          name: 'Test Platform',
          description: 'Test Description',
          url: 'http://test.example.com',
          time_zone: 'UTC',
          privacy: 'private'
        }
      end

      context 'with valid parameters' do
        before do
          post better_together.setup_wizard_step_create_host_platform_path(locale: I18n.default_locale),
               params: { platform: valid_platform_params }
        end

        it 'creates a new platform' do
          expect(Platform.count).to eq(1)
        end

        it 'sets the platform as host' do
          platform = Platform.last
          expect(platform.host).to be true
        end

        it 'marks the wizard step as completed' do
          wizard.reload
          step = wizard.wizard_steps.find_by(wizard_step_definition: platform_details_step)
          expect(step&.completed_at).to be_present
        end

        it 'redirects to the next step' do
          expect(response).to have_http_status(:redirect)
        end
      end

      context 'with invalid parameters' do
        let(:invalid_platform_params) do
          {
            name: '',
            description: '',
            url: '',
            time_zone: 'UTC',
            privacy: 'private'
          }
        end

        before do
          post better_together.setup_wizard_step_create_host_platform_path(locale: I18n.default_locale),
               params: { platform: invalid_platform_params }
        end

        it 'does not create a platform' do
          expect(Platform.count).to eq(0)
        end

        it 'renders the platform_details template' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'assigns @platform with errors' do
          expect(assigns(:platform)).to be_present
          expect(assigns(:platform).errors).to be_present
        end

        it 'sets flash alert' do
          expect(flash[:alert]).to be_present
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        before do
          allow_any_instance_of(Platform).to receive(:save!).and_raise(
            ActiveRecord::RecordInvalid.new(Platform.new)
          )

          post better_together.setup_wizard_step_create_host_platform_path(locale: I18n.default_locale),
               params: { platform: valid_platform_params }
        end

        it 'handles the exception' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets flash alert with error message' do
          expect(flash[:alert]).to be_present
        end
      end
    end

    describe 'GET #admin_creation' do
      before do
        create(:platform, host: true)
        get better_together.setup_wizard_step_admin_creation_path(locale: I18n.default_locale)
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'assigns @user' do
        expect(assigns(:user)).to be_a(User)
        expect(assigns(:user)).to be_new_record
      end

      it 'builds person association for user' do
        expect(assigns(:user).person).to be_present
        expect(assigns(:user).person).to be_new_record
      end

      it 'assigns @form' do
        expect(assigns(:form)).to be_a(BetterTogether::HostPlatformAdminForm)
      end
    end

    describe 'POST #create_admin' do
      let!(:host_platform) { create(:platform, host: true) }
      let!(:host_community) { create(:community, creator: create(:person)) }
      let!(:platform_manager_role) { create(:role, identifier: 'platform_manager') }
      let!(:governance_role) { create(:role, identifier: 'community_governance_council') }

      let(:valid_user_params) do
        {
          email: 'admin@example.com',
          password: 'password123',
          password_confirmation: 'password123',
          person_attributes: {
            identifier: 'admin-user',
            name: 'Admin User',
            description: 'Platform Administrator'
          }
        }
      end

      before do
        allow_any_instance_of(described_class).to receive_message_chain(:helpers, :host_platform)
          .and_return(host_platform)
        allow_any_instance_of(described_class).to receive_message_chain(:helpers, :host_community)
          .and_return(host_community)
      end

      context 'with valid parameters' do
        before do
          post better_together.setup_wizard_step_create_admin_path(locale: I18n.default_locale),
               params: { user: valid_user_params }
        end

        it 'creates a new user' do
          expect(User.count).to eq(1)
        end

        it 'creates associated person' do
          user = User.last
          expect(user.person).to be_present
          expect(user.person.name).to eq('Admin User')
        end

        it 'creates platform membership with platform_manager role' do
          user = User.last
          membership = host_platform.person_platform_memberships.find_by(member: user.person)
          expect(membership).to be_present
          expect(membership.role).to eq(platform_manager_role)
        end

        it 'creates community membership with governance role' do
          user = User.last
          membership = host_community.person_community_memberships.find_by(member: user.person)
          expect(membership).to be_present
          expect(membership.role).to eq(governance_role)
        end

        it 'sets user as community creator' do
          user = User.last
          host_community.reload
          expect(host_community.creator).to eq(user.person)
        end

        it 'marks the wizard step as completed' do
          wizard.reload
          step = wizard.wizard_steps.find_by(wizard_step_definition: admin_creation_step)
          expect(step&.completed_at).to be_present
        end

        it 'redirects to appropriate location' do
          expect(response).to have_http_status(:redirect)
        end
      end

      context 'with invalid parameters' do
        let(:invalid_user_params) do
          {
            email: 'invalid-email',
            password: 'short',
            password_confirmation: 'different',
            person_attributes: {
              identifier: '',
              name: '',
              description: ''
            }
          }
        end

        before do
          post better_together.setup_wizard_step_create_admin_path(locale: I18n.default_locale),
               params: { user: invalid_user_params }
        end

        it 'does not create a user' do
          expect(User.count).to eq(0)
        end

        it 'renders the admin_creation template' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'assigns @user with errors' do
          expect(assigns(:user)).to be_present
        end

        it 'sets flash alert' do
          expect(flash[:alert]).to be_present
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        before do
          allow_any_instance_of(User).to receive(:save!).and_raise(
            ActiveRecord::RecordInvalid.new(User.new)
          )

          post better_together.setup_wizard_step_create_admin_path(locale: I18n.default_locale),
               params: { user: valid_user_params }
        end

        it 'handles the exception' do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'sets flash alert with error message' do
          expect(flash[:alert]).to be_present
        end

        it 'builds person association if missing' do
          expect(assigns(:user).person).to be_present
        end
      end
    end

    describe 'GET #redirect' do
      context 'with valid path' do
        it 'redirects to platform_details' do
          get better_together.setup_wizard_step_redirect_path(locale: I18n.default_locale),
              params: { path: 'platform_details' }
          expect(response).to have_http_status(:redirect)
        end

        it 'redirects to create_host_platform' do
          get better_together.setup_wizard_step_redirect_path(locale: I18n.default_locale),
              params: { path: 'create_host_platform' }
          expect(response).to have_http_status(:redirect)
        end

        it 'redirects to admin_creation' do
          get better_together.setup_wizard_step_redirect_path(locale: I18n.default_locale),
              params: { path: 'admin_creation' }
          expect(response).to have_http_status(:redirect)
        end

        it 'redirects to create_admin' do
          get better_together.setup_wizard_step_redirect_path(locale: I18n.default_locale),
              params: { path: 'create_admin' }
          expect(response).to have_http_status(:redirect)
        end
      end

      context 'with invalid path' do
        it 'handles invalid path safely' do
          get better_together.setup_wizard_step_redirect_path(locale: I18n.default_locale),
              params: { path: 'invalid_path' }
          # Expect error handling or no redirect
          expect(response).to have_http_status(:found).or have_http_status(:ok)
        end
      end
    end

    describe 'private methods' do
      let(:controller) { described_class.new }

      describe '#permitted_path' do
        it 'allows platform_details' do
          expect(controller.send(:permitted_path, 'platform_details')).to eq('platform_details')
        end

        it 'allows create_host_platform' do
          expect(controller.send(:permitted_path, 'create_host_platform')).to eq('create_host_platform')
        end

        it 'allows admin_creation' do
          expect(controller.send(:permitted_path, 'admin_creation')).to eq('admin_creation')
        end

        it 'allows create_admin' do
          expect(controller.send(:permitted_path, 'create_admin')).to eq('create_admin')
        end

        it 'returns nil for invalid path' do
          expect(controller.send(:permitted_path, 'invalid_path')).to be_nil
        end
      end

      describe '#base_platform' do
        before do
          allow(controller).to receive_message_chain(:helpers, :base_url).and_return('http://test.example.com')
        end

        it 'creates a platform with default attributes' do
          platform = controller.send(:base_platform)
          expect(platform).to be_a(Platform)
          expect(platform.privacy).to eq('private')
          expect(platform.protected).to be true
          expect(platform.host).to be true
          expect(platform.time_zone).to eq(Time.zone.name)
        end
      end
    end
  end
end
