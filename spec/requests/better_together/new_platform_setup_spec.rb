# frozen_string_literal: true

require 'rails_helper'

# Kickoff and step-continuation both reuse PlatformPolicy#create?/#update?, whose
# can_manage_platform_settings? has a global manage_platform fallback — so the
# :as_platform_manager host-platform steward is authorized for every action here
# without any extra per-draft-platform membership grant.
RSpec.describe 'BetterTogether::NewPlatformSetup', :as_platform_manager do
  let(:locale) { I18n.default_locale }

  let!(:platform_steward_role) do
    BetterTogether::Role.find_or_create_by(identifier: 'platform_steward') do |role|
      role.name = 'Platform Steward'
      role.resource_type = 'BetterTogether::Platform'
    end
  end
  let!(:governance_role) do
    BetterTogether::Role.find_or_create_by(identifier: 'community_governance_council') do |role|
      role.name = 'Community Governance Council'
      role.resource_type = 'BetterTogether::Community'
    end
  end
  let!(:community_member_role) do
    BetterTogether::Role.find_or_create_by(identifier: 'community_member') do |role|
      role.name = 'Community Member'
      role.resource_type = 'BetterTogether::Community'
    end
  end

  def start_wizard
    get better_together.new_platform_setup_path(locale:)
    BetterTogether::Platform.order(created_at: :desc).first
  end

  describe 'GET #start' do
    it 'creates a draft platform and its paired wizard' do
      expect { start_wizard }.to change(BetterTogether::Platform, :count).by(1)
                                                                         .and change(BetterTogether::Wizard, :count).by(1)
    end

    it 'redirects to the welcome step for the new draft platform' do
      draft = start_wizard
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_welcome_path(platform_id: draft.to_param, locale:)
      )
    end

    # Nested metadata must explicitly clear the outer :as_platform_manager tag —
    # RSpec metadata is inherited, and setup_authentication_if_needed checks
    # manager tags with higher priority than :as_user, so without this override
    # the "unauthorized" example would silently still authenticate as manager.
    context 'when the current user is not permitted to manage platforms', :as_user, as_platform_manager: false do
      it 'does not create a draft platform' do
        expect { start_wizard }.not_to change(BetterTogether::Platform, :count)
      end

      it 'renders not found' do
        start_wizard
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe 'full happy path through the wizard' do
    let(:draft) { start_wizard }
    let(:platform_suffix) { SecureRandom.hex(6) }
    let(:valid_identity_params) do
      {
        name: "Tenant Platform #{platform_suffix}",
        description: 'A place where neighbors and friends support each other.',
        host_url: "https://tenant-#{platform_suffix}.example.com",
        time_zone: 'UTC',
        privacy: 'private'
      }
    end
    let(:valid_steward_params) do
      {
        email: "steward-#{platform_suffix}@example.com",
        password: '!StrongPass12345?',
        password_confirmation: '!StrongPass12345?',
        person_attributes: {
          identifier: "steward-#{platform_suffix}",
          name: 'New Platform Steward',
          description: 'First steward of this new platform.'
        }
      }
    end

    before do
      draft # kick off the wizard first so it exists before each example body runs
    end

    it 'advances from welcome to platform_identity on locale submission' do
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: 'en' }
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_platform_identity_path(platform_id: draft.to_param, locale: 'en')
      )
    end

    it 'saves platform identity and advances to the domain step' do
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
           params: { platform: valid_identity_params }

      draft.reload
      expect(draft.name).to eq(valid_identity_params[:name])
      expect(draft.host_url).to eq(valid_identity_params[:host_url])
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_domain_path(platform_id: draft.to_param, locale:)
      )
    end

    it 'skips the domain step without creating an extra domain and advances to steward_account' do
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
           params: { platform: valid_identity_params }

      expect do
        post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
             params: { skip_step: '1' }
      end.not_to change(BetterTogether::PlatformDomain, :count)

      expect(response).to redirect_to(
        better_together.new_platform_setup_step_steward_account_path(platform_id: draft.to_param, locale:)
      )
    end

    it 'adds an extra domain when a hostname is submitted and advances to steward_account' do
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
           params: { platform: valid_identity_params }

      expect do
        post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
             params: { platform_domain: { hostname: "alias-#{platform_suffix}.example.com" } }
      end.to change(BetterTogether::PlatformDomain, :count).by(1)

      extra_domain = draft.platform_domains.find_by(hostname: "alias-#{platform_suffix}.example.com")
      expect(extra_domain).to be_present
      expect(extra_domain.primary_flag).to be false
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_steward_account_path(platform_id: draft.to_param, locale:)
      )
    end

    it 'creates the steward account, memberships, and completes the wizard' do
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
           params: { platform: valid_identity_params }
      post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
           params: { skip_step: '1' }

      expect do
        post better_together.new_platform_setup_step_create_steward_account_path(platform_id: draft.to_param, locale:),
             params: { user: valid_steward_params }
      end.to change(BetterTogether::User, :count).by(1)

      draft.reload
      steward_user = BetterTogether::User.find_by(email: valid_steward_params[:email])
      expect(steward_user).to be_present
      expect(steward_user.person.name).to eq('New Platform Steward')

      platform_membership = draft.person_platform_memberships.find_by(member: steward_user.person)
      expect(platform_membership).to be_present
      expect(platform_membership.role).to eq(platform_steward_role)

      primary_community = draft.primary_community
      community_membership = primary_community.person_community_memberships.find_by(member: steward_user.person)
      expect(community_membership).to be_present
      expect(community_membership.role).to eq(governance_role)
      expect(primary_community.creator).to eq(steward_user.person)

      # steward_account isn't the last step, so the wizard isn't complete yet.
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_invite_members_path(platform_id: draft.to_param, locale:)
      )

      post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
           params: { skip_step: '1' }

      wizard = BetterTogether::Wizard.for_platform(draft)
                                     .find_by(identifier: BetterTogether::NewPlatformSetupWizardBuilder::IDENTIFIER)
      expect(wizard.completed?).to be true
      expect(response).to redirect_to(better_together.platform_path(draft, locale:))
      follow_redirect!
      expect(flash[:notice]).to eq(
        I18n.t('better_together.new_platform_setup_steps.success_message', locale:)
      )
    end
  end

  describe 'invite_members step' do
    let(:draft) { start_wizard }
    let(:platform_suffix) { SecureRandom.hex(6) }
    let(:valid_identity_params) do
      {
        name: "Tenant Platform #{platform_suffix}",
        description: 'A place where neighbors and friends support each other.',
        host_url: "https://tenant-#{platform_suffix}.example.com",
        time_zone: 'UTC',
        privacy: 'private'
      }
    end
    let(:valid_steward_params) do
      {
        email: "steward-#{platform_suffix}@example.com",
        password: '!StrongPass12345?',
        password_confirmation: '!StrongPass12345?',
        person_attributes: {
          identifier: "steward-#{platform_suffix}",
          name: 'New Platform Steward',
          description: 'First steward of this new platform.'
        }
      }
    end
    let(:steward_person) { BetterTogether::User.find_by(email: valid_steward_params[:email]).person }

    before do
      draft
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
           params: { platform: valid_identity_params }
      post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
           params: { skip_step: '1' }
      post better_together.new_platform_setup_step_create_steward_account_path(platform_id: draft.to_param, locale:),
           params: { user: valid_steward_params }
    end

    it 'skips invite_members without creating an invitation and completes the wizard' do
      expect do
        post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
             params: { skip_step: '1' }
      end.not_to change(BetterTogether::PlatformInvitation, :count)

      expect(response).to redirect_to(better_together.platform_path(draft, locale:))
    end

    it 'also treats a blank invitee_email as a skip and advances the wizard' do
      expect do
        post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
             params: { platform_invitation: { invitee_email: '' } }
      end.not_to change(BetterTogether::PlatformInvitation, :count)

      expect(response).to redirect_to(better_together.platform_path(draft, locale:))
    end

    it 'creates a pending invitation attributed to the new steward and redisplays the step' do
      invitee_email = "member-#{platform_suffix}@example.com"

      expect do
        post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
             params: { platform_invitation: { invitee_email: } }
      end.to change(BetterTogether::PlatformInvitation, :count).by(1)

      invitation = draft.invitations.find_by(invitee_email:)
      expect(invitation).to be_present
      expect(invitation.invitable).to eq(draft)
      expect(invitation.inviter).to eq(steward_person)
      expect(invitation.status_pending?).to be true
      expect(invitation.community_role).to eq(community_member_role)

      # Redisplays the same step (rather than advancing) so more invitations
      # can be sent before the steward chooses to continue.
      expect(response).to redirect_to(
        better_together.new_platform_setup_step_invite_members_path(platform_id: draft.to_param, locale:)
      )

      wizard = BetterTogether::Wizard.for_platform(draft)
                                     .find_by(identifier: BetterTogether::NewPlatformSetupWizardBuilder::IDENTIFIER)
      expect(wizard.completed?).to be false
    end

    it 'does not create an invitation with an invalid email and re-renders the step' do
      expect do
        post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
             params: { platform_invitation: { invitee_email: 'not-an-email' } }
      end.not_to change(BetterTogether::PlatformInvitation, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'does not allow a duplicate invitee_email for the same platform' do
      invitee_email = "member-#{platform_suffix}@example.com"
      post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
           params: { platform_invitation: { invitee_email: } }

      expect do
        post better_together.new_platform_setup_step_create_invite_members_path(platform_id: draft.to_param, locale:),
             params: { platform_invitation: { invitee_email: } }
      end.not_to change(BetterTogether::PlatformInvitation, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'validation failures' do
    let(:draft) { start_wizard }

    before do
      draft
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
    end

    context 'platform_identity with invalid parameters' do
      let(:invalid_identity_params) do
        {
          name: '',
          description: '',
          host_url: '',
          time_zone: 'UTC',
          privacy: 'private'
        }
      end

      before do
        post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
             params: { platform: invalid_identity_params }
      end

      it 'does not update the draft platform name' do
        expect(draft.reload.name).not_to eq('')
      end

      it 'renders the platform_identity template with an error status' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'displays validation errors' do
        expect(response.body).to match(/error|invalid|please/i)
      end

      it 'sets flash alert' do
        expect(flash.now[:alert]).to be_present
      end
    end

    context 'domain with invalid parameters' do
      let(:valid_identity_params) do
        {
          name: "Tenant Platform #{SecureRandom.hex(6)}",
          description: 'A place where neighbors and friends support each other.',
          host_url: "https://tenant-#{SecureRandom.hex(6)}.example.com",
          time_zone: 'UTC',
          privacy: 'private'
        }
      end

      before do
        post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
             params: { platform: valid_identity_params }
      end

      it 'does not create a duplicate domain' do
        draft.reload
        duplicate_hostname = draft.primary_platform_domain.hostname

        expect do
          post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
               params: { platform_domain: { hostname: duplicate_hostname } }
        end.not_to change(BetterTogether::PlatformDomain, :count)
      end

      it 'renders the domain template with an error status' do
        draft.reload
        duplicate_hostname = draft.primary_platform_domain.hostname

        post better_together.new_platform_setup_step_create_domain_path(platform_id: draft.to_param, locale:),
             params: { platform_domain: { hostname: duplicate_hostname } }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end

    context 'steward_account with invalid parameters' do
      let(:valid_identity_params) do
        {
          name: "Tenant Platform #{SecureRandom.hex(6)}",
          description: 'A place where neighbors and friends support each other.',
          host_url: "https://tenant-#{SecureRandom.hex(6)}.example.com",
          time_zone: 'UTC',
          privacy: 'private'
        }
      end
      let(:invalid_steward_params) do
        {
          email: 'not-an-email',
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
        post better_together.new_platform_setup_step_create_platform_identity_path(platform_id: draft.to_param, locale:),
             params: { platform: valid_identity_params }
      end

      it 'does not create a user' do
        expect do
          post better_together.new_platform_setup_step_create_steward_account_path(platform_id: draft.to_param, locale:),
               params: { user: invalid_steward_params }
        end.not_to change(BetterTogether::User, :count)
      end

      it 'renders the steward_account template with an error status' do
        post better_together.new_platform_setup_step_create_steward_account_path(platform_id: draft.to_param, locale:),
             params: { user: invalid_steward_params }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe 'already-completed guard' do
    let(:draft) { start_wizard }

    before do
      wizard = BetterTogether::Wizard.for_platform(draft)
                                     .find_by(identifier: BetterTogether::NewPlatformSetupWizardBuilder::IDENTIFIER)
      wizard.update!(current_completions: 1, first_completed_at: Time.current, last_completed_at: Time.current)
    end

    it 'rejects a GET to a step with the wizard-outcome success redirect' do
      # determine_wizard_outcome (inherited, not skipped for GET actions) intercepts
      # the completed case before the controller's own ensure_wizard_incomplete guard
      # ever runs — it redirects to the wizard's stored success_path with a notice.
      get better_together.new_platform_setup_step_welcome_path(platform_id: draft.to_param, locale:)
      expect(response).to redirect_to(better_together.platform_path(draft, locale:))
      follow_redirect!
      expect(flash[:notice]).to be_present
    end

    it 'rejects a POST to a step with the already_completed alert' do
      # update_welcome/create_platform_identity/create_steward_account all skip
      # determine_wizard_outcome, so ensure_wizard_incomplete is the guard that
      # actually fires here — mirrors SetupWizardStepsController's own precedent.
      post better_together.new_platform_setup_step_update_welcome_path(platform_id: draft.to_param, locale:),
           params: { locale: locale.to_s }
      expect(response).to redirect_to(better_together.platform_path(draft, locale:))
      follow_redirect!
      expect(flash[:alert]).to eq(
        I18n.t('better_together.new_platform_setup_steps.already_completed', locale:)
      )
    end
  end
end
