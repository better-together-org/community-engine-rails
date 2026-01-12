# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/ModuleLength
module BetterTogether
  RSpec.describe SetupWizardStepsController, :skip_host_setup do
    let(:wizard) { Wizard.find_or_create_by!(identifier: 'host_setup') }
    let(:platform_details_step) do
      WizardStepDefinition.find_or_create_by!(
        wizard:,
        identifier: 'platform_details'
      ) do |step|
        step.step_number = 1
        step.template = 'better_together/setup_wizard_steps/platform_details'
      end
    end
    let(:admin_creation_step) do
      WizardStepDefinition.find_or_create_by!(
        wizard:,
        identifier: 'admin_creation'
      ) do |step|
        step.step_number = 2
        step.template = 'better_together/setup_wizard_steps/admin_creation'
      end
    end

    before do
      # Ensure wizard exists and steps are loaded
      platform_details_step
      admin_creation_step

      # Reset wizard completion status for fresh testing
      wizard.update!(
        current_completions: 0,
        first_completed_at: nil,
        last_completed_at: nil
      )
      wizard.wizard_steps.destroy_all
    end

    describe 'GET #platform_details' do
      before do
        get better_together.setup_wizard_step_platform_details_path(locale: I18n.default_locale)
      end

      it 'returns http success' do
        expect(response).to have_http_status(:success)
      end

      it 'renders the platform details form' do
        expect(response.body).to include('name')
        expect(response.body).to include('description')
        expect(response.body).to include('url')
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
          expect(step&.completed).to be true
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
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'displays validation errors' do
          expect(response.body).to include('alert-warning').or include("can't be blank")
        end

        it 'sets flash alert' do
          expect(flash[:alert]).to be_present
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        before do
          # Create a platform with a validation error
          invalid_platform = Platform.new
          invalid_platform.errors.add(:base, 'Test validation error')

          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(Platform).to receive(:save!).and_raise(
            ActiveRecord::RecordInvalid.new(invalid_platform)
          )
          # rubocop:enable RSpec/AnyInstance

          post better_together.setup_wizard_step_create_host_platform_path(locale: I18n.default_locale),
               params: { platform: valid_platform_params }
        end

        it 'handles the exception' do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'shows error message in response' do
          # flash.now is used in controller, which renders error in the response body
          # Check that error-related content is displayed
          expect(response.body).to match(/error|invalid|please/i)
        end
      end
    end

    describe 'GET #admin_creation' do
      it 'redirects to appropriate step based on wizard state' do
        skip 'Complex wizard state management - covered by integration tests'
      end
    end

    describe 'POST #create_admin' do
      # The wizard creates the FIRST user - no pre-existing users should exist
      # The host platform and community are created in the previous wizard step (create_host_platform)
      # Use find_or_create_by to handle seed data
      before do
        ::BetterTogether::Platform.find_or_create_by(host: true) do |platform|
          platform.name = 'Test Platform'
          platform.url = 'http://test.example.com'
          platform.privacy = 'public'
          platform.identifier = 'test-platform'
          platform.time_zone = 'UTC'
        end

        ::BetterTogether::Community.find_or_create_by(host: true) do |community|
          community.name = 'Test Community'
          community.identifier = 'test-community'
        end

        # Ensure no users exist before the wizard creates the first one
        ::BetterTogether::User.destroy_all
      end

      # Roles must exist for memberships to be created
      let!(:platform_manager_role) do
        ::BetterTogether::Role.find_or_create_by(identifier: 'platform_manager') do |role|
          role.name = 'Platform Manager'
          role.resource_type = 'BetterTogether::Platform'
        end
      end
      let!(:governance_role) do
        ::BetterTogether::Role.find_or_create_by(identifier: 'community_governance_council') do |role|
          role.name = 'Community Governance Council'
          role.resource_type = 'BetterTogether::Community'
        end
      end

      let(:valid_user_params) do
        {
          email: 'admin@example.com',
          password: '!StrongPass12345?',
          password_confirmation: '!StrongPass12345?',
          person_attributes: {
            identifier: 'admin-user',
            name: 'Admin User',
            description: 'Platform Administrator'
          }
        }
      end

      # No need to stub helpers since host_platform/host_community exist in DB

      context 'with valid parameters' do
        before do
          # Wizard should start with ZERO users and create the first one
          raise "Expected 0 users before wizard creates first admin, found #{User.count}" unless User.none?

          post better_together.setup_wizard_step_create_admin_path(locale: I18n.default_locale),
               params: { user: valid_user_params }
        end

        it 'creates a new user' do
          expect(User.count).to eq(1)
        end

        it 'creates associated person' do
          user = User.find_by(email: 'admin@example.com')
          expect(user).to be_present
          expect(user.person).to be_present
          expect(user.person.name).to eq('Admin User')
        end

        it 'creates platform membership with platform_manager role' do
          user = User.find_by(email: 'admin@example.com')
          host_platform = ::BetterTogether::Platform.find_by(host: true)
          membership = host_platform.person_platform_memberships.find_by(member: user.person)
          expect(membership).to be_present
          expect(membership.role).to eq(platform_manager_role)
        end

        it 'creates community membership with governance role' do
          user = User.find_by(email: 'admin@example.com')
          host_community = ::BetterTogether::Community.find_by(host: true)
          membership = host_community.person_community_memberships.find_by(member: user.person)
          expect(membership).to be_present
          expect(membership.role).to eq(governance_role)
        end

        it 'sets user as community creator' do
          user = User.find_by(email: 'admin@example.com')
          host_community = ::BetterTogether::Community.find_by(host: true)
          host_community.reload
          expect(host_community.creator).to eq(user.person)
        end

        it 'marks the wizard step as completed' do
          wizard.reload

          # Find the step that should be completed
          step = wizard.wizard_steps.find_by(identifier: 'admin_creation')

          # The step should exist and be marked as completed
          expect(step).to be_present
          expect(step.completed).to be(true)
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
            person: {
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
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'displays validation errors in response' do
          expect(response.body).to match(/error|invalid/i)
        end

        it 'sets flash alert' do
          expect(flash[:alert]).to be_present
        end
      end

      context 'when ActiveRecord::RecordInvalid is raised' do
        before do
          # Create a user with a validation error
          invalid_user = User.new
          invalid_user.errors.add(:base, 'Test validation error')

          # rubocop:disable RSpec/AnyInstance
          allow_any_instance_of(User).to receive(:save!).and_raise(
            ActiveRecord::RecordInvalid.new(invalid_user)
          )
          # rubocop:enable RSpec/AnyInstance

          post better_together.setup_wizard_step_create_admin_path(locale: I18n.default_locale),
               params: { user: valid_user_params }
        end

        it 'handles the exception' do
          expect(response).to have_http_status(:unprocessable_content)
        end

        it 'shows error message in response' do
          # flash.now is used in controller, which renders error in the response body
          # Check that error-related content is displayed
          expect(response.body).to match(/error|invalid|please/i)
        end

        it 'renders the form again' do
          expect(response.body).to match(/email|password/i)
        end
      end
    end

    describe 'GET #redirect' do
      context 'with valid path' do
        it 'redirects based on wizard state' do
          skip 'Complex wizard navigation logic - tested through actual wizard flow'
        end
      end

      context 'with invalid path' do
        it 'handles invalid path safely' do
          skip 'Route constraints prevent invalid paths from reaching controller'
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
          # rubocop:disable RSpec/MessageChain
          allow(controller).to receive_message_chain(:helpers, :base_url).and_return('http://test.example.com')
          # rubocop:enable RSpec/MessageChain
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
# rubocop:enable Metrics/ModuleLength
